

function compute_symmetry(g::MetaGraphsNext.MetaGraph, color_class::Dict{Int, Set{Int}})
    vcolor_class = Vector{Set{Int}}()
    for color_set in values(color_class)
        push!(vcolor_class, color_set)
    end
    canon_label, generators, orbit_class = Traces.traces(g.graph, false, true, vcolor_class)
    var_orbit_class, ref_generators =  var_orbit(g, orbit_class)
    var_generators, ref_orbit_class = var_generator(g, generators)
    return var_orbit_class, ref_orbit_class, var_generator, ref_generators
end


# find all variable vertex orbits
function var_orbit(g::MetaGraphsNext.MetaGraph, orbit_class::Vector{Set{Int}})
    var_orbit_class = Vector{Vector{Int}}(undef, 0)
    ref_orbit_class = Vector{Vector{JuMP.VariableRef}}(undef, 0)
    for class in orbit_class
        oclass = [var_id for var_id in class]
        if typeof(g[Symbol(oclass[1])].ref) == JuMP.VariableRef
            push!(var_orbit_class, oclass)
            push!(ref_orbit_class, [g[Symbol(var_id)].ref for var_id in oclass])
        end
    end
    return var_orbit_class, ref_orbit_class
end

# find all variable vertex generators
function var_generator(g::MetaGraphsNext.MetaGraph, generators::Vector{Vector{Vector{Int}}})
    var_generators = Vector{Vector{Vector{Int}}}(undef, 0)
    ref_generators = Vector{Vector{Vector{JuMP.VariableRef}}}(undef, 0)
    for perm in generators
        var_perm = Vector{Vector{Int}}(undef, 0)
        ref_perm = Vector{Vector{JuMP.VariableRef}}(undef, 0)
        for cycle in perm
            if typeof(g[Symbol(cycle[1])].ref) == JuMP.VariableRef
                push!(var_perm, cycle)
                push!(ref_perm, [g[Symbol(var_id)].ref for var_id in cycle])
            end
        end
        push!(var_generators, var_perm)
        push!(ref_generators, ref_perm)
    end
    return var_generator, ref_generators
end 



# find binary reference orbits
function ref_orbit(g::MetaGraphsNext.MetaGraph, var_orbit_class::Dict{Int, Vector{Int}})
    max_size_id = 0
    max_size = -1
    ref_orbit_class = []
    ind_orbit_class = []
    i = 1
    for var_orbit in values(var_orbit_class)
        #print(g[Symbol(var_orbit[1])].ref, " ", var_orbit[1], "....")
        if JuMP.is_integer(g[Symbol(var_orbit[1])].ref) || JuMP.is_binary(g[Symbol(var_orbit[1])].ref)
            #print("in\n")
            len = length(var_orbit)
            if len > max_size
                max_size = len
                max_size_id = i
            end
            ref_orbit = [g[Symbol(ind)].ref for ind in var_orbit]
            push!(ref_orbit_class, ref_orbit)
            ind_orbit = [ind for ind in var_orbit]
            push!(ind_orbit_class, ind_orbit)
        end
        i += 1
    end
    #print(max_size, max_size_id)
    #print("\n", "max_orbit size:", max_size, "\n")
    return ref_orbit_class, ind_orbit_class, max_size_id, max_size
end


