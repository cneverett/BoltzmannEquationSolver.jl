"""
    FourFlow(u,dp,du,dE,du2)

Returns the four-flow vector Ua 'vector{Float64}' from the flattened axysmmetric distribution function f1D.
"""
function FourFlow(f1D::Vector{Float32},nump,numt,pr,ur,m)

    f2D = zeros(Float64,nump,numt)
    f2D = Float64.(reshape(f1D,(nump,numt)))

    du = zeros(Float64,numt)
    du2 = zeros(Float64,numt)
    dp = zeros(Float64,nump)
    dE = BoltzmannCollisionIntegral.deltaEVector(pr,m)

    for i in 1:numt
        du[i] = ur[i+1]-ur[i]
        du2[i] = (ur[i+1]^2-ur[i]^2)/2
    end
    for i in 1:nump 
        dp[i] = (pr[i+1]-pr[i])
    end

    # unscale by dp*du 
    for i in axes(f2D,1), j in axes(f2D,2)
        f2D[i,j] /= dp[i] * du[j]
    end

    Na = zeros(Float64,4)
    Na[1] = dp' * f2D * du
    Na[4] = dE' * f2D * du2

    return Na

end

function HydroFourVelocity(Na::Vector{Float64})

    Ua = zeros(Float64,4)

    metric = zeros(Float64,4,4)
    metric[1,1] = -1
    metric[2,2] = 1
    metric[3,3] = 1
    metric[4,4] = 1

    sqrtNa2 = sqrt(abs(Na'*metric*Na))
    Ua .= Na/sqrtNa2

    return Ua

end

function ProjectionTensor(Ua::Vector{Float64})

    Δab = zeros(Float64,4,4)

    metric = zeros(Float64,4,4)
    metric[1,1] = -1
    metric[2,2] = 1
    metric[3,3] = 1
    metric[4,4] = 1

    for i in 1:4, j in 1:4
        Δab[i,j] = metric[i,j] + Ua[i]*Ua[j]
    end

    return Δab

end

function StressEnergyTensor(f1D::Vector{Float32},nump,numt,pr,ur,m)

    f2D = zeros(Float64,nump,numt)
    f2D = Float64.(reshape(f1D,(nump,numt)))

    dp = zeros(Float64,nump)
    du = zeros(Float64,numt)
    dp2 = zeros(Float64,nump)
    du2 = zeros(Float64,numt)
    du3 = zeros(Float64,numt)
    duplusu3 = zeros(Float64,numt)
    dpfunc = zeros(Float64,nump)
    dE = BoltzmannCollisionIntegral.deltaEVector(pr,m)

    pr64 = Float64.(pr)

    Tab = zeros(Float64,4,4)

    for i in 1:numt
        du[i] = ur[i+1]-ur[i]
        du2[i] = (ur[i+1]^2-ur[i]^2)/2
        du3[i] = (ur[i+1]^3-ur[i]^3)/3
        duplusu3[i] = ur[i+1]-ur[i] - (ur[i+1]^3-ur[i]^3)/3
    end
    for i in 1:nump 
        dp[i] = (pr[i+1]-pr[i])
        dp2[i] = (pr[i+1]^2-pr[i]^2)/2
        if m == 0e0
            dpfunc[i] = pr64[i+1]^2 - pr64[i]^2
        else
            if pr[i+1]/m < 1e-3
                dpfunc[i] = 2/3 * pr[i+1]^3/m - 1/5 * pr[i+1]^5/m^3
                dpfunc[i] -= 2/3 * pr[i]^3/m - 1/5 * pr[i]^5/m^3
            else
                dpfunc[i] = pr64[i+1]*sqrt(pr64[i+1]^2+m^2) - m^2*atanh(pr64[i+1]/sqrt(pr64[i+1]^2+m^2))
                dpfunc[i] -= pr64[i]*sqrt(pr64[i]^2+m^2) - m^2*atanh(pr64[i]/sqrt(pr64[i]^2+m^2))
            end
        end

    end

    # unscale by dp*du
    for i in axes(f2D,1), j in axes(f2D,2)
        f2D[i,j] /= dp[i] * du[j]
    end

    Tab[1,1] = dE' * f2D * du

    Tab[2,2] = 1/4 * dpfunc' * f2D * duplusu3
    Tab[3,3] = Tab[2,2]

    Tab[4,4] = 1/2 * dpfunc' * f2D * du3 

    Tab[1,4] = dp2' * f2D * du2
    Tab[4,1] = Tab[1,4]
    
    return Tab
end

function ScalarNumberDensity(Na,Ua)

    metric = zeros(Float64,4,4)
    metric[1,1] = -1
    metric[2,2] = 1
    metric[3,3] = 1
    metric[4,4] = 1

    if Na[1] == 0
        n = 0
    else
        n = -Na'*metric*Ua
    end

    return n

end

function ScalarEnergyDensity(Tab,Ua,n)

    metric = zeros(Float64,4,4)
    metric[1,1] = -1
    metric[2,2] = 1
    metric[3,3] = 1
    metric[4,4] = 1

    en = (metric * Ua)' * Tab * (metric * Ua)

    if n == 0
        e = 0
    else
        e = en/n
    end

    return e

end

function ScalarPressure(Tab,Δab)

    metric = zeros(Float64,4,4)
    metric[1,1] = -1
    metric[2,2] = 1
    metric[3,3] = 1
    metric[4,4] = 1

    p = (1/3) * sum(Tab .* (metric * Δab * metric))

    return p

end

function ScalarTemperature(p,n)

    kb = 1.38f-23
    c = 3f8
    mEle = 9.11e-31
    T = p/(n*kb) * mEle * c^2

    return T

end

# Obselete functions ======== #
# =========================== #

    """
        numberDensity(u,dp,dμ;mode="AXI")

    Returns the average number density of a distribution function `u` output from solver. Number density is defined as the zeroth moment of the distribution function. i.e. 
        ```math
        n = \\int \\mathrm{d}p\\mathrm{d}\\mu f(p,μ) = \\sum_{i,j} f_{ij} \\Delta p_i \\Delta μ_j
        ``` 
    where `dp` = ``\\Delta p_i`` is a vector of momentum intervals and `dμ` = ``\\Delta μ_j`` is a vector of cosine (momentum space) angle intervals.
    """
    function NumberDensity(u::Vector{Float32},nump,numt,dp::Vector{Float32},dμ::Vector{Float32};mode="AXI")

        if mode=="AXI"
            f = reshape(u,(nump,numt))
            # unscale by dp*dμ 
            #for i in axes(f,1), j in axes(f,2)
            #    f[i,j] /= dp[i] * dμ[j]
            #end
            n = dp' * f * dμ
        elseif mode=="ISO"
            f = u
            n = dp' * f * 2 # 2 is total range of dμ
        end  
        
        return n
        
    end

    """
        momentum(f0,dp,meanp,dμ;mode="AXI")

    Returns the average momentum of a distribution function `u` output from solver. average momentum is defined as the first moment of the distribution function. i.e. 
        ```math
        \\braket{p} = \\frac{\\int \\mathrm{d}p\\mathrm{d}\\mu pf(p,μ)}{n} = \\sum_{i,j} f_{ij} \\Delta p_i\\braket{p}_i \\Delta μ_j / n
        ``` 
    where `dp` = ``\\Delta p_i`` is a vector of momentum intervals, `meanp` = ``\\braket{p}_i`` is a vector of the average momentum value per bin, `dμ` = ``\\Delta μ_j`` is a vector of cosine (momentum space) angle intervals, and `numberDensity` = ``n`` is the average number density calculated using the function [`numberDensity`](@ref).
    """
    function Momentum(u::Vector{Float32},nump,numt,dp::Vector{Float32},meanp::Vector{Float32},dμ::Vector{Float32},numberDensity::Float32;mode="AXI")

        
        dpmeanp = dp .* meanp
        
        if mode=="AXI"
            f = reshape(u,(nump,numt))
            #for i in axes(f,1), j in axes(f,2)
            #    f[i,j] /= dp[i] * dμ[j]
            #end
            momentum = dpmeanp' * f * dμ
        elseif mode=="ISO"
            f = u
            momentum = dpmeanp' * f * 2 # 2 is total range of dμ
        end
    
        momentum /= numberDensity

        return momentum
    end


    """
        Energy(f0,ΔE,dμ,numberDensity)

    Returns the average TOTAL energy of a distribution function `u` output from solver. average energy is defined as the first moment of the distribution function. i.e. 
        ```math
        \\braket{p} = \\frac{\\int \\mathrm{d}p\\mathrm{d}\\mu p^0f(p,μ)}{n} = \\sum_{i,j} f_{ij} \\Delta E_i \\Delta μ_j / n
        ``` 
    where `ΔE` = ``\\Delta E_i`` is a vector of the average "energy" value per bin (has dimensions of momentum squared), `dμ` = ``\\Delta μ_j`` is a vector of cosine (momentum space) angle intervals, and `numberDensity` = ``n`` is the average number density calculated using the function [`numberDensity`](@ref).
    """
    function Energy(u::Vector{Float32},nump,numt,ΔE::Vector{Float32},dp::Vector{Float32},dμ::Vector{Float32},numberDensity::Float32;mode="AXI")


        if mode=="AXI"
            f = reshape(u,(nump,numt))
            for i in axes(f,1), j in axes(f,2)
                f[i,j] /= dp[i] * dμ[j]
            end
            energy = ΔE' * f * dμ
        elseif mode=="ISO"
            f = u
            energy = ΔE' * f * 2 # 2 is total range of dμ
        end

        energy /= numberDensity

        return energy
        
    end


