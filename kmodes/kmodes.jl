module KModes

"""
Based on the Python implementation here: https://github.com/nicodv/kmodes
"""

using DataStructures: DefaultDict
using StatsBase: sample

export kmodes

mutable struct KmodesResult
    assignments::Array{Int64,1}
    cost::Int64
    cost_history::Array{Int64,1}
    converged::Bool
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
Randomly initializes k centroids by picking k random instances from X
Returns a A x K matrix, where A is the number of features of each
    instance of x (each column is a centroid).
"""
function random_centroid_init(X, k)
    idx = sample(1:size(X,2), k, replace=false)
    centroids = collect(hcat([X[:, i] for i in idx]...))
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
            cl_attr_freq[clust][attr] += 1
        end
    end
    return
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
                centroids[attr_idx, clust_idx] = rand(X[attr_idx, :]) # replace centroid attrs w random sample
            else
                # change attribute to the mode of this cluster
                mode_idx = argmax(collect(values(cl_attr_freq[clust_idx]))) # dict idx of most frequent attribute
                mode = collect(keys(cl_attr_freq[clust_idx]))[mode_idx] # attribute associated with the above index
                centroids[attr_idx, clust_idx] = mode
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
        cl_attr_freq[old_clust_idx][attr] -= 1 # decrement count from old cluster
        cl_attr_freq[clust_idx][attr] += 1 # increment count in new cluster
        
        # if the new attribute's frequency is greater than the centroid's,
        # then the new attribute freq is the new mode. update the centroid.
        curr_mode = centroids[attr_idx, clust_idx] # the old mode (possibly no longer true mode)
        if cl_attr_freq[clust_idx][curr_mode] < cl_attr_freq[clust_idx][attr] # compare frequencies
            centroids[attr_idx, clust_idx] = attr # update centroid to have the mode
        end
        
        # if this attribute was the mode of the old cluster, it may no longer be the mode after
        # we changed the old cluster's attribute frequencies
        if attr == centroids[attr_idx, old_clust_idx] # if attribute = previous cluster's mode:
            # recalculate the mode of the old cluster
            mode_idx = argmax(collect(values(cl_attr_freq[old_clust_idx]))) # dict idx of most frequent attribute
            mode = collect(keys(cl_attr_freq[old_clust_idx]))[mode_idx] # attribute associated with the above index
            centroids[attr_idx, old_clust_idx] = mode
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
"""
function kmodes(X::Array{Int64, 2}, k::Int64; init=random_centroid_init, max_iter=50)
    println("KModes! Remember: instances in columns, features in rows.")
    @assert k < size(X, 2) "There must be fewer clusters than points"

    membership = zeros(Bool, (k, size(X, 2))) # rows = clusters, cols = points
    
    # dict of dicts: cluster_idx => dict with keys = attributes, values = frequencies  
    cl_attr_freq = DefaultDict{Int64, DefaultDict{Int64,Int64,Int64}}(()->DefaultDict{Int64,Int64}(0))

    centroids = init(X, k) # initialize centroids (each column is a centroid)

    assign_clusters!(centroids, membership, cl_attr_freq, X) # initial cluster assignments

    # initial centroid update (change centroid attributes to be the modes of their clusters)
    update_centroids!(centroids, cl_attr_freq, membership, X)

    iter = 0
    converged = false
    cost = total_cost(centroids, X)

    cost_history = [cost]

    while iter <= max_iter && !converged
        iter += 1
        moves = 0
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
        converged = (moves == 0) # || (new_cost >= cost) # check if converged (no moves, or cost increased)
        cost = new_cost
        push!(cost_history, cost)
    end
    assignments = [argmax(centroids) for centroids in eachcol(membership)]
    return KmodesResult(assignments, cost, cost_history, converged)
end

end # module

# TODO: are the convergence criteria correct?