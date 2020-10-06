module test

using Test
include("kmodes.jl")
kmodes = KModes.kmodes

@testset "basic kmodes" begin
    X = [4 4 5]
    res = kmodes(X, 1)
    @test res.assignments = [1,1,1]
    @test in(res.centroids[1,1], X)
    @test res.cost == 1
    @test res.converged

    res = kmodes(X, 2; init=[3 5])
    @test res.cost == 0
    @test res.converged
end


end # module