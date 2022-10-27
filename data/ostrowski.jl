using JuMP

model = Model()

rag = 1:24
@variables(model,
begin
    x[rag], Bin
end
)
cycle = 1:8

@constraints(model,
begin
    [i in 1:7], x[i] + x[i+1] <= 1
    x[8] + x[1] <= 1
    [i in cycle], x[i] + x[2*i+7] <= 1
    [i in cycle], x[i] + x[2*i+8] <= 1
    [i in cycle], x[2*i + 7] + x[2*i+8] <= 1
end
)

@objective(model, Max, sum(x[i] for i in rag) )


# orbits = ((1:8), (9:24))

write_to_file(model, "ostrowski.mps")