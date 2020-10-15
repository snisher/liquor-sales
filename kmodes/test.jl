module test

using Test
include("kmodes.jl")
kmodes = KModes.kmodes

@testset "single centroid" begin
    X = [3 4 5]
    res = kmodes(X, 1)
    @test res.assignments = [1,1,1]
    @test in(res.centroids[1,1], X)
    @test res.cost == 1
    @test res.converged
end

@testset "two centroids, manual centroid init" begin
    X = [3 4 5]
    res = kmodes(X, 2; init=[3 6])
    @test res.cost == 0
    @test res.converged
end

@testset "two centroids, Huang centroid init" begin
    X = [3 4 5]
    res = kmodes(X, 2; init_alg=KModes.huang_centroid_init)
    @test res.cost == 0
    @test res.converged
end

@testset "two centroids, random centroid init" begin
    X = [3 4 5]
    res = kmodes(X, 2; init_alg=KModes.random_centroid_init)
    @test res.cost == 0
    @test res.converged
end

@testset "no convergence/max_iter" begin
    X = [4 5 5; 1 2 3]
    res = kmodes(X, 2; init=[0 0; 7 7], max_iter=0)
    @test !res.converged
end

end # module