module KModes

"""
Based on the Python implementation here: https://github.com/nicodv/kmodes
"""

using DataStructures: DefaultDict
using StatsBase: sample

export kmodes, random_centroid_init, huang_centroid_init

mutable struct KmodesResult
    converged::Bool
    assignments::Array{Int64,1}
    cost::Int64
    cost_history::Array{Int64,1}
    centroids::Array{Int64,2}
end

"""
Hamming distance = number of locations that differ between to vectors.
"""
hamming(a, b) = sum(a .!= b)

"""
get the costs (hamming distances) from this point to each centroid in centroids.
"""
centroid_costs(centroids, point) = map(ctrd->hamming(ctrd, point), eachcol(centroids))

"""
Randomly initializes k centroids by picking k random instances from X.
Returns a A x K matrix, where A is the number of features of each
    instance of x (each column is a centroid).
"""
function random_centroid_init(X, k)
    idx = sample(1:size(X,2), k, replace=false) # indices of k random points (no duplicates)
    centroids = collect(hcat([X[:, i] for i in idx]...)) # collect all points into a matrix
    return centroids
end

"""
Initialize centroids as described by Huang in the K-modes paper.
Returns a A x K matrix, where A is the number of features of each
    instance of x (each column is a centroid).
"""
function huang_centroid_init(X, k)
    n_attrs = size(X, 1)
    centroids = zeros(Int64, n_attrs, k)
    
    # Randomly choose attributes for each centroid. More common attributes are 
    #     naturally chosen more frequently, reflecting attribute probabilities.
    for attr_idx in 1:n_attrs
        possibilities = X[attr_idx, :] # all possible attributes
        centroids[attr_idx, :] = transpose(rand(possibilities, k)) # a random k attributes
    end

    # previously chosen centroids may create empty clusters, so re-initialize each centroid
    #     to the closest point in the data.
    for (centroid_idx, centroid) in enumerate(eachcol(centroids)) # for each centroid
        dists = [hamming(centroid, x) for x in eachcol(X)] # hamming distance to each data point
        closest_x = argmin(dists) # index of the closest point
        centroids[:, centroid_idx] = X[:, closest_x]
    end
    return centroids
end

"""
Assigns points to closest centroid by Hamming distance.
Mutates centroids, membership, and cl_attr_freq.
returns nothing.
"""
function assign_clusters!(centroids, membership, cl_attr_freq, X)
    for (point_idx, point) in enumerate(eachcol(X))
        clust = argmin(centroid_costs(centroids, point)) # idx of closest centroid
        membership[clust, point_idx] = 1 # record which cluster this point was assigned to

        # record how many times each attribute appears in this cluster
        for (attr_idx, attr) in enumerate(point)
            cl_attr_freq[clust][attr_idx][attr] += 1
        end
    end
    return
end

"""
Gets the mode of the attributes from a cluster from the cl_attr_freq dict
returns the mode::Int64
"""
function cl_attr_freq_mode(cl_attr_freq, clust_idx, attr_idx)
    possible_attrs = [pair for pair in cl_attr_freq[clust_idx][attr_idx]] # get all attr => freq pairs
    mode_idx = argmax([pair[2] for pair in possible_attrs]) # idx of most frequent attribute (pair[2] is the frequency)
    return possible_attrs[mode_idx][1] # attribute associated with the above index
end

"""
Updates each centroid's attributes to the modes of its cluster.
Mutates centroids and cl_attr_freq.
returns nothing.
"""
function update_centroids!(centroids, cl_attr_freq, membership, X)
    for clust_idx = 1:size(centroids,2) # for each cluster
        for attr_idx = 1:size(centroids, 1) # for each attribute
            if sum(membership[clust_idx, :]) == 0 # if no points are assigned to this cluster
                possible_attrs = X[attr_idx, :]
                used_attrs = centroids[attr_idx, :]
                # in(arr) creates a function returning whether argument is in arr
                new_attrs_idx = in(used_attrs).(possible_attrs) .== 0 # only non-duplicate attrs
                # if there are only duplicate attrs, get all attrs, otherwise get the non-duplicates only
                new_attrs = sum(new_attrs_idx) == 0 ? possible_attrs : possible_attrs[new_attrs_idx]
                centroids[attr_idx, clust_idx] = rand(new_attrs) # random sample
            else
                # change attribute to the mode of this cluster
                centroids[attr_idx, clust_idx] = cl_attr_freq_mode(cl_attr_freq, clust_idx, attr_idx)
            end
        end
    end
    return
end

"""
Changes a point from one cluster to another. Modifies centroids, membership,
and cl_attr_freq accordingly.
Returns nothing.
"""
function change_point_clust!(centroids, membership, cl_attr_freq,
                            point_idx, point, clust_idx, old_clust_idx)
    membership[old_clust_idx, point_idx] = 0 # remove affiliation with old cluster
    membership[clust_idx, point_idx] = 1 # assign point to new cluster
    
    # update the cluster-attribute-frequencies dict
    for (attr_idx, attr) in enumerate(point)
        cl_attr_freq[old_clust_idx][attr_idx][attr] -= 1 # decrement count from old cluster
        cl_attr_freq[clust_idx][attr_idx][attr] += 1 # increment count in new cluster
        
        # if the new attribute's frequency is greater than the centroid's,
        # then the new attribute freq is the new mode. update the centroid.
        curr_mode = centroids[attr_idx, clust_idx] # the old mode (possibly no longer true mode)
        if cl_attr_freq[clust_idx][attr_idx][curr_mode] < cl_attr_freq[clust_idx][attr_idx][attr] # compare frequencies
            centroids[attr_idx, clust_idx] = attr # update centroid to have the mode
        end
        
        # if this attribute was the mode of the old cluster, it may no longer be the mode after
        # we changed the old cluster's attribute frequencies
        if attr == centroids[attr_idx, old_clust_idx] # if attribute = previous cluster's mode:
            # recalculate the mode of the old cluster
            centroids[attr_idx, old_clust_idx] = cl_attr_freq_mode(cl_attr_freq, clust_idx, attr_idx)
        end
    end
    return
end

"""
Calculates the total cost (sum of hamming distances) from each point to its cluster's centroid.
returns the total cost.
"""
function total_cost(centroids, X)
    cost = 0
    for point in eachcol(X)
        cost += minimum(centroid_costs(centroids, point))
    end
    return cost
end

"""
The K-Modes algorithm. Like K-Means, except uses the mode. For categorical data.
    arg init::Array{Int64,2} - initial centroid positions. Each column = centroid.
    arg init_alg - function that initializes centroids.
    max_iter::Int64 - maximum number of iterations.
"""
function kmodes(X::Array{Int64, 2}, k::Int64; init=nothing, init_alg=huang_centroid_init, max_iter=50)
    println("KModes! Remember: instances in columns, features in rows.")
    @assert k < size(X,2) "There must be fewer clusters than points"
    if !isnothing(init)
        @assert size(init,1) == size(X,1) "Expected $(size(X,1)) features per centroid. Got $(size(init,1)). Centroids must have same number of features as the data points. Remember, # features = # rows!"
        @assert size(init,2) == k "Expected $(k) centroids. Got $(size(init,2)). The number of centroids must equal k (the number of clusters). Remember, # centroids = # columns!"
    end

    membership = zeros(Bool, (k, size(X, 2))) # rows = clusters, cols = points

    # triple nested dict... dict[c] = cluster, dict[c][a] = attribute 'a' of cluster 'c', dict[c][a][attr] = frequency of attr a
    cl_attr_freq = DefaultDict(()->DefaultDict(()->DefaultDict(0))) # TODO: better to specify types in the defaultdicts?

    # initialize centroids (each column is a centroid) with alg if initial centers not provided
    centroids = isnothing(init) ? init_alg(X, k) : deepcopy(init)

    assign_clusters!(centroids, membership, cl_attr_freq, X) # initial cluster assignments

    # initial centroid update (change centroid attributes to be the modes of their clusters)
    update_centroids!(centroids, cl_attr_freq, membership, X)

    iter = 0
    converged = false
    cost = total_cost(centroids, X)

    cost_history = [cost]

    while iter < max_iter && !converged
        iter += 1
        moves = 0

        # make copies so if the update is worse we can return these
        old_centroids = deepcopy(centroids)
        old_membership = deepcopy(membership)

        for (point_idx, point) in enumerate(eachcol(X))
            clust_idx = argmin(centroid_costs(centroids, point)) # idx of closest centroid
            old_clust_idx = argmax(membership[:, point_idx] .== 1) # idx of previous centroid
            if membership[clust_idx, point_idx] # if the point is already assigned to the right cluster:
                continue
            end
            
            # if here, point is not with the right cluster
            moves += 1
            change_point_clust!(centroids, membership, cl_attr_freq, point_idx, point, clust_idx, old_clust_idx)

            # check if no points are now assigned to the cluster this point just moved from.
            # if so, re-initialize to random point from the largest cluster
            if sum(membership[old_clust_idx, :]) == 0 # if no points assigned to this cluster
                largest_cluster_idx = argmax(sum(membership, dims=2))[1] # returns cartesian coordinates, get just the row
                rand_point_idx = rand(findall(membership[largest_cluster_idx, :]))
                rand_point = X[:, rand_point_idx]
                change_point_clust!(centroids, membership, cl_attr_freq,
                                rand_point_idx, rand_point, old_clust_idx, largest_cluster_idx)
            end
        end
        new_cost = total_cost(centroids, X)

        # if this iteration resulted in greater cost, return clusters from the previous iteration
        if new_cost > cost
            converged = true
            assignments = [argmax(centroids) for centroids in eachcol(old_membership)]
            return KmodesResult(converged, assignments, cost, cost_history, old_centroids)
        end

        cost = new_cost
        push!(cost_history, cost)

        # if no moves were made, return these clusters
        if moves == 0
            converged = true
            assignments = [argmax(centroids) for centroids in eachcol(membership)]
            return KmodesResult(converged, assignments, cost, cost_history, centroids)
        end
    end
    # max iterations
    assignments = [argmax(centroids) for centroids in eachcol(membership)]
    return KmodesResult(converged, assignments, cost, cost_history, centroids)
end

end # module

# TODO: other centroid initialization functions (Huang and Coa) + time complexities of these