

import CPLEX, Gurobi

function read_from(filename::String)
    jump_model = JuMP.read_from_file(filename)
    return jump_model
end


function optimize_mip!(mip::MIP, solver_name::String)
    model = mip.work_model
    # set solver
    if solver_name == "Gurobi"  
        JuMP.set_optimizer(model, Gurobi.Optimizer) 
        JuMP.set_optimizer_attribute(model, "Threads", 1)
        JuMP.set_optimizer_attribute(model, "OutputFlag", 0)
        JuMP.set_optimizer_attribute(model, "TimeLimit", 600) # note Gurobi only supports wall-clock time
    elseif solver_name == "CPLEX"
        JuMP.set_optimizer(model, CPLEX.Optimizer) 
        JuMP.set_optimizer_attribute(model, "CPXPARAM_Threads", 1)
        JuMP.set_optimizer_attribute(model, "CPXPARAM_TimeLimit", 600)
    elseif solver_name == "SCIP"

    else
        println("unkown solver name\n")
    end
    
    JuMP.print(model)

    JuMP.optimize!(model)


    bound = JuMP.objective_bound(model)
    gap = JuMP.relative_gap(model)
    time = JuMP.solve_time(model)
    obj_val = JuMP.objective_value(model)
    print("\n bound: ", bound, " gap: ", gap, " time: ", time, " obj_val: ", obj_val, "\n")
end



export read_from,  optimize_mip!