using SymMIP

function test_liberti()
    model  = read_from("../data/liberti.mps")
    sym_analysis!(model)
end



function test_sts27()
    model  = read_from("../data/sts27.lp")
    sym_analysis!(model)
end

function test_ostrowski()
    model  = read_from("../data/ostrowski.mps")
    sym_analysis!(model)
end

test_liberti()
test_ostrowski()
test_sts27()