function BoltzmannEquationSolver(u0,timespan,Lists; method = ROCK4()#= Rodas3P(autodiff=false,linsolve = KrylovJL_GMRES()) =##=ImplicitEuler(autodiff=false, linsolve = KrylovJL_GMRES())=#)

    deriv_cpu = BoltzmannEquation(Lists);

    prob = ODEProblem(deriv_cpu,u0,timespan)

    @time solution = solve(prob,method, maxiters = 1e4, isoutofdomain = (u,p,t)->any(x->x<0,u))

    return solution

end

function (g::BoltzmannEquation)(du,u,p,t)

    # limit u
    #@. u = u*(u>1e-20)

    # update f_list based on current u
    u_to_f_list!(g.f_list,u)

    # update changes due to Binary S and T interactions
    update_ΔSΔT!(g,CollisionMatricies)

    # assign du
    j = 0
    for i in 1:length(g.f_list)
        k = length(g.f_list[i]) # nump_list[i]*numt_list[i]
        @view(du[(1+j):(j+k)]) .= g.ΔfS_list[i] - g.ΔfT_list[i]
        j += k
    end

    #limit du    
    #dt = (t-g.t)
    #@. du = du*(abs(du)>=1e-15)

    #update t
    #g.t = t


end

function update_ΔSΔT!(g::BoltzmannEquation,CollisionMatricies)

    f_list = g.f_list
    interaction_list = g.interaction_list
    name_list = g.name_list
    ΔfS_list = g.ΔfS_list
    ΔfT_list = g.ΔfT_list

    for i in eachindex(interaction_list)
        interaction = interaction_list[i]
        matricies = CollisionMatricies[interaction]
        name1 = interaction[1]
        name1_loc = findfirst(==(name1),name_list)
        name2 = interaction[2]
        name2_loc = findfirst(==(name2),name_list)
        name3 = interaction[3]
        name3_loc = findfirst(==(name3),name_list)
        name4 = interaction[4]
        name4_loc = findfirst(==(name4),name_list)

        if (name1 == name2) && (name3 == name4)
            SMatrix = matricies[1]
            TMatrix = matricies[2]
            fill!(ΔfS_list[name3_loc],Float32(0))
            fill!(ΔfT_list[name1_loc],Float32(0))
            @turbo for i in axes(SMatrix,1), j in axes(SMatrix,2) ,k in axes(SMatrix,3) 
                ΔfS_list[name3_loc][i] += SMatrix[i,j,k] * f_list[name2_loc][j] * f_list[name1_loc][k] 
            end
            @turbo for i in axes(TMatrix,1), j in axes(TMatrix,2)
                ΔfT_list[name1_loc][i] += TMatrix[i,j] * f_list[name2_loc][i] * f_list[name1_loc][j]
            end
            #ΔS_list[name3_loc] .= (SMatrix * f_list[name2_loc])' * f_list[name1_loc]             
            #ΔT_list[name1_loc] .= (TMatrix * f_list[name2_loc]) .* f_list[name1_loc]
        end
    
        #=if (name1 == name2) && (name3 != name4)
            SMatrix3 = matricies[1]
            SMatrix4 = matricies[2]
            TMatrix = matricies[3]
            ΔS_list[name3_loc] .= (SMatrix3 * f_list[name2_loc])' * f_list[name1_loc]
            ΔS_list[name4_loc] .= (SMatrix4 * f_list[name2_loc])' * f_list[name1_loc]
            ΔT_list[name1_loc] .= (TMatrix * f_list[name2_loc]) .* f_list[name1_loc]
        end
    
        if (name1 != name2) && (name3 == name4)
            SMatrix = matricies[1]
            TMatrix1 = matricies[2]
            TMatrix2 = matricies[3]
            ΔS_list[name3_loc] .= (SMatrix * f_list[name2_loc])' * f_list[name1_loc]
            ΔT_list[name1_loc] .= (TMatrix1 * f_list[name2_loc]) .* f_list[name1_loc]
            ΔT_list[name2_loc] .= (TMatrix2 * f_list[name1_loc]) .* f_list[name2_loc]
        end
    
        if (name1 != name2) && (name3 != name4)
            SMatrix3 = matricies[1]
            SMatrix4 = matricies[2]
            TMatrix1 = matricies[3]
            TMatrix2 = matricies[4]
            ΔS_list[name3_loc] .= (SMatrix3 * f_list[name2_loc])' * f_list[name1_loc]
            ΔS_list[name4_loc] .= (SMatrix4 * f_list[name2_loc])' * f_list[name1_loc]
            ΔT_list[name1_loc] .= (TMatrix1 * f_list[name2_loc]) .* f_list[name1_loc]
            ΔT_list[name2_loc] .= (TMatrix2 * f_list[name1_loc]) .* f_list[name2_loc]
        end=#

    end

end


