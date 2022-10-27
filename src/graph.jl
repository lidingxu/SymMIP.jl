const Color = Int # -1: self-color, 0: uncolorder, positive: color
@inline ToSymbol(ind::Int, vtype::Symbol) = Symbol(string(vtype == :var ? "v" : "c", ind))


mutable struct BPVertex
    ind::Int
    ref::Union{JuMP.VariableRef, JuMP.ConstraintRef}
    color::Color

    function BPVertex(ind::Int, ref::Union{JuMP.VariableRef, JuMP.ConstraintRef}, color::Color)
        vertex = new(ind, ref, color)
        return vertex
    end
end

mutable struct BPEdge
    endinds::Tuple{Int,Int} # (varind, consind)
    refs::Tuple{JuMP.VariableRef, JuMP.ConstraintRef}
    color::Color
    weight::Float64

    function BPEdge(endinds::Tuple{Int,Int}, ref::Tuple{JuMP.VariableRef, JuMP.ConstraintRef}, color::Color, weight::Float64)
        edge = new(endinds, ref, color, weight)
        return edge
    end
end


const SetTypes = [MOI.GreaterThan{Float64}, MOI.EqualTo{Float64}, MOI.LessThan{Float64}]
const Exprs2Sets = Dict([(JuMP.AffExpr, SetTypes)])
Base.isless(a::JuMP.VariableRef, b::JuMP.VariableRef) = Symbol(a) < Symbol(b)
Base.isless(a::JuMP.ConstraintRef, b::JuMP.ConstraintRef) = Symbol(a) < Symbol(b)

# bipg, vars2vind map index of variables in indmap, cons2vind map index of constraints in indmap
# color from 1 
function build_bip_graph(model::JuMP.Model, epsilon::Float64)
    color = 1
    bipg, vars2vind, cons2vind, indmap = bipartite_graph(model, epsilon)
    color, var_colors = color_variables(model, bipg, vars2vind, epsilon, color)
    color, con_colors = color_constraints(model, bipg, cons2vind, epsilon, color)
    color, edge_colors = color_edges(model, bipg, epsilon, color)
    #printg(bipg)
    return bipg, var_colors, con_colors, edge_colors
end



# a bipartite graph, left nodes are variables, right nodes are constraints
function bipartite_graph(model::JuMP.Model, epsilon)
    g = MetaGraphsNext.MetaGraph(Graphs.Graph(), VertexData = BPVertex, EdgeData = BPEdge)
    #g = MetaGraphsNext.MetaGraph(Graphs.Graph(), VertexData = String, EdgeData = String)
    
    vars2vind = Dict{JuMP.VariableRef, Int}()
    cons2vind = Dict{JuMP.ConstraintRef, Int}()
    indmap = Vector{Union{JuMP.VariableRef, JuMP.ConstraintRef}}()
    # add variable nodes
    for var_ref in JuMP.all_variables(model)
        push!(indmap, var_ref)
        vind= length(indmap)
        vars2vind[var_ref] = vind
        MetaGraphsNext.add_vertex!(g, ToSymbol(vind, :var), BPVertex(vind, var_ref, 0))
    end

    # add constraint node
    # add edges
    for (functype, settypes) in Exprs2Sets
        for settype in settypes
            for con_ref in JuMP.all_constraints(model, functype, settype)
                push!(indmap, con_ref)
                cind = length(indmap)
                cons2vind[con_ref] = cind
                MetaGraphsNext.add_vertex!(g, ToSymbol(cind, :cons), BPVertex(cind, con_ref, 0))
                for var_ref in JuMP.all_variables(model)
                    coeff = JuMP.normalized_coefficient(con_ref, var_ref)
                    if abs(coeff) > epsilon
                        vind = vars2vind[var_ref]
                        MetaGraphsNext.add_edge!(g, ToSymbol(vind, :var), ToSymbol(cind, :cons), BPEdge((vind, cind), (var_ref, con_ref), 0, coeff))
                        #print(coeff, " ")
                    end
                end
            end
        end
    end
    return g, vars2vind, cons2vind, indmap
end

function edge_color_graph(model::JuMP.Model)

end


function printg(g::MetaGraphsNext.MetaGraph)
    print("numvar:", MetaGraphsNext.nv(g), " numedge:", MetaGraphsNext.ne(g), "\n")
    for vertex in  MetaGraphsNext.vertices(g)
        vlabel = g.vertex_labels[vertex]
        print(vertex, " ", g[vlabel], "\n")
    end
    for (edge, edge_data) in g.edge_data
        print(edge, " ", edge_data, "\n")#, " ", g.vertex_labels[edge[1]])# get_edge_data(g, edge[1], edge[2]), "\n")
    end
end



# find all vairables' colors
function color_variables(model::JuMP.Model, g::MetaGraphsNext.MetaGraph, vars2vind::Dict{JuMP.VariableRef, Int}, epsilon::Float64, color::Color)
    sort_vars = Vector{Tuple{Int, Float64, Float64, Float64, JuMP.VariableRef}}(undef, JuMP.num_variables(model))  # (vtype, coefficient, lb, ub, VariableRef), vtype: 0 integer, 1 continuous 
    obj = JuMP.objective_function(model)
    i = 1
    colors = []
    # record variable info
    for var in JuMP.all_variables(model)
        coef =  get(obj.terms, var, 0.0)
        vtype = ( JuMP.is_integer(var) || JuMP.is_binary(var) ) ? 0 : 1
        lb = JuMP.is_binary(var) ? 0 : (JuMP.has_lower_bound(var) ? JuMP.lower_bound(var) : -Inf)
        ub =  JuMP.is_binary(var) ? 1 : (JuMP.has_lower_bound(var) ? JuMP.lower_bound(var) : -Inf)
        sort_vars[i] = (vtype, coef, lb, ub, var)
        i += 1
    end
    sort!(sort_vars)

    # color the same variable
    prev = sort_vars[1]
    var = prev[5]
    vind = vars2vind[var]
    g[ToSymbol(vind, :var)].color =  color
    push!(colors, color)
    for curr in sort_vars[2:end]
        var = curr[5]
        vind = vars2vind[var]
        if curr[1] == prev[1] && abs(curr[2] - prev[2]) < epsilon && abs(curr[3] - prev[3]) < epsilon && abs(curr[4] - prev[4]) < epsilon
            g[ToSymbol(vind, :var)].color =  color
        else 
            color += 1
            g[ToSymbol(vind, :var)].color = color
            push!(colors, color)
        end
        prev = curr
    end
    color += 1
    return color, colors
end



# find all constraints' colors
function color_constraints(model::JuMP.Model, g::MetaGraphsNext.MetaGraph, cons2vind::Dict{JuMP.ConstraintRef, Int}, epsilon::Float64, color::Color)
    sort_cons = Vector{Tuple{Int, Float64, Int, JuMP.ConstraintRef}}()  # (ctype, rhs, numvars, ConstraintRef), ctype: 0 LessThan, 1 EqualTo, 2 GreaterThan
    
    colors = []
    for (functype, settypes) in Exprs2Sets
        for settype in settypes
            for con_ref in JuMP.all_constraints(model, functype, settype)
                if settype == MOI.GreaterThan{Float64}
                    ctype = 0
                elseif settype == MOI.EqualTo{Float64}
                    ctype = 1
                elseif settype == MOI.LessThan{Float64}
                    ctype = 2
                end
                rhs = JuMP.normalized_rhs(con_ref)
                cind = cons2vind[con_ref]
                numvars =  Graphs.degree(g.graph, MetaGraphsNext.code_for(g, ToSymbol(cind, :cons)))# length(Graphs.SimpleGraphs.adj(g.graph,  MetaGraphsNext.code_for(g,ToSymbol(cind, :cons))))
                push!(sort_cons, (ctype, rhs, numvars, con_ref))
            end
        end
    end   

    sort!(sort_cons)

    # color the same constraints
    prev = sort_cons[1]
    con = prev[4]
    cind = cons2vind[con]
    g[ToSymbol(cind, :cons)].color = color
    push!(colors, color)
    for curr in sort_cons[2:end]
        con = curr[4]
        cind = cons2vind[con]
        if curr[1] == prev[1] && abs(curr[2] - prev[2]) < epsilon && curr[3] == prev[3]
            g[ToSymbol(cind, :cons)].color = color
        else 
            color += 1
            g[ToSymbol(cind, :cons)].color = color
            push!(colors, color)
        end
        prev = curr
    end
    color += 1
    return color, colors
end

# find all constraint matrix coefficients (edges) ' color
function color_edges(model::JuMP.Model, g::MetaGraphsNext.MetaGraph, epsilon::Float64, color::Color)
    sort_edges = Vector{Tuple{Float64, Tuple{Symbol, Symbol}}}() # (coefficient, edge) )
    for (edge, edge_data) in g.edge_data
        push!(sort_edges, (edge_data.weight, edge))
    end

    sort!(sort_edges)
    
    colors = []
    prev = sort_edges[1]
    edge = prev[2]
    g.edge_data[edge].color = color
    push!(colors, color)
    for curr in sort_edges[2:end]
        edge = curr[2]
        if abs(curr[1] - prev[1]) < epsilon 
            g.edge_data[edge].color = color
        else 
            color += 1
            g.edge_data[edge].color = color
            push!(colors, color)
        end
        prev = curr
    end
    color += 1
    return color, colors
end


mutable struct LayerVertex
    ind::Int # layer index
    b_ind::Int  # corresponding bipartite index
    layer_p_ind::Int # parent index in layer graph, 0 for non-parent
    ref::Union{JuMP.VariableRef, JuMP.ConstraintRef, Nothing}
    color::Color


    function LayerVertex(ind::Int, b_ind::Int, layer_p_ind::Int, ref::Union{JuMP.VariableRef, JuMP.ConstraintRef, Nothing}, color::Color)
        vertex = new(ind, b_ind, layer_p_ind, ref, color)
        return vertex
    end
end

mutable struct LayerEdge
    endinds::Tuple{Int,Int} # (varind, consind)
    etype::String

    function LayerEdge(endinds::Tuple{Int,Int}, etype::String)
        edge = new(endinds, etype)
        return edge
    end
end


function build_layer_graph(bipg::MetaGraphsNext.MetaGraph, bp_var_colors, bp_con_colors, bp_edge_colors)
    layerg = MetaGraphsNext.MetaGraph(Graphs.Graph(), VertexData = LayerVertex, EdgeData = LayerEdge)

    color_map = Dict{Int, Union{Int, String}}() # bipartite color to layer color
    vind_map = Dict{Int, Int}() # bipartite vind to layer vind
    color_class = Dict{Int, Set{Int}}()

    log_nedge_colors = round(Int, log(2, length(bp_edge_colors) + 1))

    print("\n", length(bp_edge_colors), " ", log_nedge_colors, "\n")

    color = 1
    for (i, edge_color) in enumerate(bp_edge_colors)
        color_map[edge_color] =  bitstring(i)[end - log_nedge_colors + 1:end]
        #print(color_map[edge_color])
        color_class[color] = Set{Int}()
        color += 1
    end


    for con_color in bp_con_colors
        color_map[con_color] = color
        color_class[color] = Set{Int}()
        color += 1
    end

    for var_color in bp_var_colors
        color_map[var_color] = color
        color_class[color] = Set{Int}()
        color += 1
    end


    # add bipartite_graph vertices with log(Edge_colors) 
    ind = 1
    lind_aux_map =  Dict{Tuple{Int, Int}, Int}()

    for vertex in MetaGraphsNext.vertices(bipg)
        vlabel = bipg.vertex_labels[vertex]
        bip_v = bipg[vlabel]
        vind_map[bip_v.ind] = ind
        layer_p_ind = ind
        color = color_map[bip_v.color]
        push!(color_class[color], ind)
        MetaGraphsNext.add_vertex!(layerg, Symbol(ind), LayerVertex(ind, bip_v.ind, 0, bip_v.ref, color)) # bipg[vlabel]
        ind += 1
        # for each vertex, add log(Edge_colors) vertices with log(Edge_colors)
        for k in 1:log_nedge_colors
            push!(color_class[k], ind)
            MetaGraphsNext.add_vertex!(layerg, Symbol(ind), LayerVertex(ind, bip_v.ind, layer_p_ind, nothing, k))   
            MetaGraphsNext.add_edge!(layerg, Symbol(layer_p_ind), Symbol(ind), LayerEdge((layer_p_ind, ind), "replicate"))
            lind_aux_map[(layer_p_ind, k)] = ind
            ind += 1 
        end
    end

    #print(lind_aux_map)

    # add edges
    for (edge, edge_data) in bipg.edge_data
        ind1 = edge_data.endinds[1]
        ind1 = vind_map[ind1]
        ind2 = edge_data.endinds[2]
        ind2 = vind_map[ind2]
        color =  edge_data.color
        bitsrep = bitstring(color)[end - log_nedge_colors + 1:end]
        for (k, onebit) in enumerate(bitsrep)
            bit =  onebit == "0" ? false : true
            if bit
            # k
                ind1k = lind_aux_map[(ind1,k)]
                ind2k = lind_aux_map[(ind2,k)]
                MetaGraphsNext.add_edge!(layerg, Symbol(ind1k), Symbol(ind2k),  LayerEdge((ind1k, ind2k), "cross"))
            end
        end
        #print(edge, " ", edge_data, "\n")#, " ", g.vertex_labels[edge[1]])# get_edge_data(g, edge[1], edge[2]), "\n")
    end

    printg(layerg)
    return layerg, color_map, vind_map, lind_aux_map, color_class
end


# assign a set vertices with their own colors
function fix_color!(layerg::MetaGraphsNext.MetaGraph, color_class::Dict{Int, Set{Int}}, ind_orbit_break::Vector{Int})
    max_color = 0
    for color_id in keys(color_class)
        max_color = max_color > color_id ? max_color : color_id
    end

    
    for ind in ind_orbit_break
        max_color += 1
        prev_color = layerg[Symbol(ind)].color
        layerg[Symbol(ind)].color =  max_color
        # out
        delete!(color_class[prev_color], ind)
        # new color
        color_class[max_color] = Set([ind])
    end
end
