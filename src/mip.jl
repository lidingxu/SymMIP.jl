

mutable struct Option
    epsilon::Float64  # numerical tolerance
 
    function Option(epsilon::Float64 = 1e-6)
        option = new(epsilon)
        return option
    end
end

mutable struct MIP
    init_model::JuMP.Model
    option::Option
    work_model::JuMP.Model
    reference_map::JuMP.ReferenceMap

    function MIP(init_model::JuMP.Model, option::Option)
        mip = new(init_model, option)
        return mip
    end

end

# check whether the mip is supported
function is_supported(mip::MIP)
    all_vars = JuMP.all_variables(mip.init_model)
    isMIP = false
    for var in all_vars
        if JuMP.is_integer(var) || JuMP.is_binary(var)
            isMIP = true
            break
        end
    end
    return isMIP
end

# Ax (<)= b, x in X
function preprocess(mip::MIP)
    model = mip.init_model
    #@JuMP.constraint(model, JuMP.all_variables(model)[1] + JuMP.all_variables(model)[2] >= 5)
    to_delete = Vector{JuMP.ConstraintRef}()
    check_conss = JuMP.all_constraints(model, JuMP.AffExpr, MOI.GreaterThan{Float64})
    for con_ref in check_conss
        push!(to_delete, con_ref)
        rhs = JuMP.normalized_rhs(con_ref)
        name = JuMP.name(con_ref)
        rev_cons = @JuMP.constraint(model, sum(-JuMP.normalized_coefficient(con_ref, var_ref) * var_ref for var_ref in JuMP.all_variables(model)) <= -rhs)
        JuMP.set_name(rev_cons,  string("r", name))
    end
    for con_ref in to_delete
        JuMP.delete(model, con_ref)
        JuMP.unregister(model, :con_ref)
    end
    #show(model)
    work_model, reference_map = JuMP.copy_model(model)
    mip.work_model = work_model
    mip.reference_map = reference_map
end


function sym_analysis!(model::JuMP.Model, epsilon::Float64 = 1e-6)
    option = Option(1e-6)
    mip = MIP(model, option)
    if !is_supported(mip)
        print("the MIP model is not supported! The supported model is: MIP\n")
        return mip
    end

    preprocess(mip)
    bipg, var_colors, con_colors, edge_colors = build_bip_graph(mip.work_model, mip.option.epsilon)
    layerg, color_map, vind_map, lind_aux_map, color_class = build_layer_graph(bipg, var_colors, con_colors, edge_colors)
    var_orbit_class, ref_orbit_class, var_generator, ref_generators  = compute_symmetry(layerg, color_class)


    print("\n", ref_orbit_class, "\n ", ref_generators, "\n")
    return ref_orbit_class, ref_generators
end


function sym_break!(mip::MIP)
#=
    if !is_supported(mip)
        print("the MIP model is not supported! The supported model is: MIP\n")
        return mip
    end

    preprocess(mip)

    if mip.option.orbit_break_method == 0
        print("the symmetry breaking is not used\n")
        return mip
    end

    #print(mip.init_model)
    bipg, var_colors, con_colors, edge_colors = build_bip_graph(mip.work_model, mip.option.epsilon)
    layerg, color_map, vind_map, lind_aux_map, color_class = build_layer_graph(bipg, var_colors, con_colors, edge_colors)

    var_orbit_class, var_generator = compute_symmetry(layerg, color_class)

    ref_orbit_class, ind_orbit_class, max_size_id, max_size = ref_orbit(layerg, var_orbit_class)
    #print(var_orbit_class,  "\n")
    ref_orbit_break = ref_orbit_class[max_size_id]
    ind_orbit_break = ind_orbit_class[max_size_id]
    # narrowing
    while max_size >= 2
        # breaking
        break!(mip.work_model, ref_orbit_break, mip.option.orbit_break_method)

        # fix color class for varibale in the orbit
        fix_color!(layerg, color_class, ind_orbit_break)
        #print(color_class, "\n")

        # recompute the symmetry
        var_orbit_class, var_generator = compute_symmetry(layerg, color_class)

        print(var_orbit_class, "\n")
        # get reference orbit with max size
        ref_orbit_class, ind_orbit_class, max_size_id, max_size = ref_orbit(layerg, var_orbit_class)
        # everything is continuous
        if max_size_id == 0
            break
        end
        ref_orbit_break = ref_orbit_class[max_size_id]
        ind_orbit_break = ind_orbit_class[max_size_id]
    end
=#

end


export Option, MIP, is_supported, sym_analysis!