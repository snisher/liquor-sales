module test

using Test
include("kmodes.jl")
kmodes = KModes.kmodes

@testset "basic single centroid" begin
    X = [4 4 5]
    res = kmodes(X, 1)
    @test res.assignments = [1,1,1]
    @test in(res.centroids[1,1], X)
    @test res.cost == 1
    @test res.converged
end

@testset "basic two centroids" begin
    X = [4 4 5]
    res = kmodes(X, 2; init=[3 6])
    @test res.cost == 0
    @test res.converged
end

@testset "no convergence/max_iter" begin
    X = [4 5 6; 1 2 3]
    res = kmodes(X, 2; init=[0 0; 0 0], max_iter=1)
    @test !res.converged
end

end # module