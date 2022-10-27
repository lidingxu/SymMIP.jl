using JuMP

model = Model()

rag = 1:6
@variables(model,
begin
    x[rag], Bin
end
)

@constraints(model,
begin
    x[1] + x[2] <= 1
    x[3] + x[4] <= 1
    x[5] + x[6] <= 1
    x[1] + x[3] + x[5] <= 2
    x[2] + x[4] + x[5] <= 2
    x[1] + x[4] + x[6] <= 2
    x[2] + x[3] + x[6] <= 2
end
)

@objective(model, Min, x[1] + x[2] + 2 * x[3] + 2 * x[4] + 3 * x[5] + 3 * x[6])


# orbits = ((1 2), (3 4), (5 6))

write_to_file(model, "liberti.mps")
