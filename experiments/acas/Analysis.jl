using SNNT
using JLD
using Glob
using Images
using ImageTransformations
using Plots

function summarize_and_load(folder, prefix)
    println("Loading results from $folder/$prefix-*.jld")
    results = []
    metadata = nothing
    for file in glob("$prefix-*.jld",folder)
        if occursin("summary",file)
            continue
        end
        cur_results = load(file)
        if haskey(cur_results,"backup_meta")
            metadata = cur_results["backup_meta"]
        end
        append!(results,cur_results["result"])
    end
    result_summary = SNNT.VerifierInterface.reduce_results(results)
    save("$folder/$prefix-summary.jld","result",result_summary,"args",metadata)
    return (result_summary, metadata)
end

function acas_advisory_to_cmd(adv :: String)
    if adv=="COC"
        @warn "Encountered COC"
        return (nothing,nothing,nothing)
    elseif adv=="DNC"
        v=0
        w=-1
        alo=1
    elseif adv=="DND"
        v=0
        w=1
        alo=1
    elseif adv=="DES1500"
        v=-25
        w=-1
        alo=1
    elseif adv=="CL1500"
        v=25
        w=1
        alo=1
    elseif adv=="SDES1500"
        v=-25
        w=-1
        alo=2
    elseif adv=="SCL1500"
        v=25
        w=1
        alo=2
    elseif adv=="SDES2500"
        v=-41.67
        w=-1
        alo=2
    else
        @assert adv=="SCL2500"
        v=41.67
        w=1
        alo=2
    end
    return (v,w,alo)
end

function acas_interpret_cex(cex :: Tuple{Vector{Float32},Vector{Float32}};do_print=false)
    h = 16000*cex[1][1]
    vO = 200*cex[1][2]
    vI = 200*cex[1][3]
    tNMAC = cex[1][4]*40+20
    init_r = tNMAC*2200+500
    if do_print
        println("h : $h\t\tft")
        println("vO: $vO\t\tft/sec")
        println("vI: $vI\t\tft/sec")
        println("t : $tNMAC\t\ts")
        println("r : $init_r\t\tft")
    end
    max_val = argmax(cex[2])
    adv = nothing
    if 1 == max_val
        adv="COC"
    elseif 2 == max_val
        adv="DNC"
    elseif 3 == max_val
        adv="DND"
    elseif 4 == max_val
        adv="DES1500"
    elseif 5 == max_val
        adv="CL1500"
    elseif 6 == max_val
        adv="SDES1500"
    elseif 7 == max_val
        adv="SCL1500"
    elseif 8 == max_val
        adv="SDES2500"
    else
        @assert 9 == max_val
        adv="SCL2500"
    end
    if do_print
        println("")
        println("Advisory: $adv")
    end
    return (h,vO,vI,init_r,tNMAC,adv)
end

function acas_simulate(interpreted_cex;tau=0.1,do_print=false,vI_override=nothing)
    if isnothing(interpreted_cex[6])
        return nothing
    end
    h = interpreted_cex[1]
    vO = interpreted_cex[2]
    if !isnothing(vI_override)
        vI = vI_override
    else
        vI = interpreted_cex[3]
    end
    r = interpreted_cex[4]
    tNMAC = interpreted_cex[5]
    adv=interpreted_cex[6]
    vlo,w,alo = acas_advisory_to_cmd(adv)
    simulation_range = (tNMAC+5)/tau
    trace = [(h,r,vO,vI)]
    if do_print
        println("r: $r\t\th: $h\t\tvO: $vO")
    end
    for _ in 1:simulation_range
        v = vO-vI
        a = if (w*v >= w*vlo)
            0
        else
            if (alo==1)
                w*8.046
            else
                w*10.725
            end
        end
        r -= 2200*tau
        h -= (v*tau + a*tau^2/2)
        vO += a*tau
        if do_print
            println("r: $r\t\th: $h\t\tvO: $vO\t\ta: $a")
        end
        push!(trace,(h,r,vO,vI))
    end
    return trace
end

function acas_simulate2(interpreted_cex;tau=0.1,do_print=false)
    if isnothing(interpreted_cex[6])
        return nothing
    end
    h = interpreted_cex[1]
    vO = interpreted_cex[2]
    vI = interpreted_cex[3]
    r = interpreted_cex[4]
    tNMAC = interpreted_cex[5]
    adv=interpreted_cex[6]
    vlo,w,alo = acas_advisory_to_cmd(adv)
    simulation_range = (tNMAC+5)/tau
    trace = [(h,r,vO,vI)]
    println("r: $r\t\th: $h\t\tvO: $vO")
    for _ in 1:simulation_range
        a = if (w*vO >= w*vlo)
            0
        else
            if (alo==1)
                w*8.046
            else
                w*10.725
            end
        end
        v = vO-vI
        r -= 2200*tau
        h -= (v*tau + a*tau^2/2)
        vO += a*tau
        if do_print
            println("r: $r\t\th: $h\t\tvO: $vO\t\ta: $a")
        end
        push!(trace,(h,r,vO,vI))
    end
    return trace
end

function has_nmac(trace;hp=100,rp=500)
    return any(
        x->abs(x[1])<=hp&&abs(x[2])<=rp,
        trace)
end

function minimum_distance(trace)
    return minimum(map(x->sqrt(x[1]^2+x[2]^2),trace))
end

nmac_rectangle(;rv=2200,altitute_offset=10000) = Shape([-500/rv,500/rv,500/rv,-500/rv], [-100+altitute_offset,-100+altitute_offset,100+altitute_offset,100+altitute_offset])

function plot_trajectory(plot_name,crash_trace,cf_trace;tau=0.1,rv=2200,altitute_offset = 10000,xlims=(-6.7,6.7),ylims=(9400,10500),figsize=(1000,300),delta=2.0,imgmodifier=1.0,show_planes=false)
    # CC 0 image: https://www.rawpixel.com/image/6481821/vector-sticker-public-domain-blue
    intruder = load("intruder.png")  
    time_total = length(crash_trace)*tau
    time_to_nmac = time_total-5+500/rv
    t_ownship = -time_to_nmac:tau:(time_total-time_to_nmac)
    t_ownship = t_ownship[1:length(crash_trace)]
    t_intruder = time_to_nmac:-tau:(time_to_nmac-time_total)
    t_intruder = t_intruder[1:length(crash_trace)]
    pos_intruder = altitute_offset+crash_trace[1][1]
    h_intruder = repeat([pos_intruder],length(t_intruder))
    h_crash = [(pos_intruder-x[1]) for x in crash_trace]
    h_cf = [(pos_intruder-x[1]) for x in cf_trace]
    plot(t_ownship, h_crash,
        labels="Ownship (current advisory)",
        linestyle=:solid,
        legend=:outertopright,
        xlims=xlims, ylims=ylims,
        xlabel="time for intruder / -time for ownship (s)",
        ylabel="altitude (ft)",
        size=figsize,
        leftmargin = 30Plots.px,
        bottommargin = 40Plots.px,
        color=:blue, linewidth=3,
        tickfontsize=16,
        guidefontsize=16,
        legendfontsize=16)#,
        #aspect_ratio=3e-3)
    plot!(t_ownship, h_cf, labels="Original path of ownship",linestyle=:dash,color=:orange, linewidth=3)
    plot!(t_intruder,h_intruder, label="Intruder",color=:purple,linestyle=:dot, linewidth=3)
    plot!(nmac_rectangle(altitute_offset=pos_intruder),fopacity=.3,label="NMAC",color=:red)

    # Images
    if show_planes
        y_modifier = (ylims[2]-ylims[1])/max(xlims[2],-xlims[1])
        # Ownship
        # Compute angle
        dt = delta#tau
        dh = (h_crash[convert(Int,delta/tau)][1]-h_crash[1][1])/y_modifier
        println(dh*180/pi)
        println(dt)
        println(dh)
        theta = atan(dh/dt)
        ownship = imrotate(reverse(intruder,dims=(1,2)),theta)
        x1 = -time_to_nmac
        x2 = -time_to_nmac+delta*(size(ownship,2)/size(intruder,2))
        ownship_ratio = size(ownship,1)/size(ownship,2)
        x_center = (x1+x2)/2
        # Find index of h_cf closest to x_center
        idx = argmin(abs.(t_ownship .- x_center))
        y_center = h_cf[idx]
        y_range = (x2-x1)*ownship_ratio*y_modifier*imgmodifier
        # if theta > 0
        #     y1 = h_crash[1]-y_range*(1/8)
        #     y2 = h_crash[1]+y_range*(7/8)
        # else
        #     y1 = h_crash[1]-y_range*(7/8)
        #     y2 = h_crash[1]+y_range*(1/8)
        # end
        y1 = y_center-y_range*0.5
        y2 = y_center+y_range*0.5
        plot!([x1,x2],[y1,y2],ownship,fopacity=1.0,aspect_ratio=:none,yflip=false)
        # Intruder
        x1 = time_to_nmac-delta
        x2 = time_to_nmac
        intruder_ratio = size(intruder,1)/size(intruder,2)
        y_range = (x2-x1)*intruder_ratio*y_modifier*imgmodifier
        y1 = pos_intruder-y_range*(4/8)
        y2 = pos_intruder+y_range*(4/8)
        plot!([x1,x2],[y1,y2],reverse(intruder,dims=1),fopacity=1.0,aspect_ratio=:none,yflip=false)
    end
    #xlims=xlims, ylims=ylims,size=figsize)
    #plot!([-7.0,7.0],[9400,11000])
    savefig(plot_name)
end

function plot_trajectory2(plot_name,crash_trace,cf_trace;tau=0.1,rv=2200,altitute_offset = 10000,xlims=(-6.7,6.7),ylims=(9400,10500),figsize=(1000,300),delta=2.0,imgmodifier=1.0,show_planes=false)

    intruder = load("intruder.png")  
    time_total = length(crash_trace)*tau
    time_to_nmac = time_total-5+500/rv
    t_ownship = -time_to_nmac:tau:(time_total-time_to_nmac)
    t_ownship = t_ownship[1:length(crash_trace)]
    t_intruder = time_to_nmac:-tau:(time_to_nmac-time_total)
    t_intruder = t_intruder[1:length(crash_trace)]
    pos_intruder = altitute_offset+crash_trace[1][1]
    h_intruder = [pos_intruder + i*tau*crash_trace[1][4] for i in 1:length(t_intruder)]
    #h_intruder = repeat([pos_intruder],length(t_intruder))
    #println(h_intruder)
    #h_intruder .+= repeat([tau*crash_trace[1][4]],length(t_intruder))
    #println(repeat([tau*crash_trace[1][4]],length(t_intruder)))
    h_intruder_nmac = h_intruder[floor(Int,time_to_nmac/tau)]
    h_crash = h_intruder .- [(x[1]) for x in crash_trace]
    h_cf = h_intruder .- [(x[1]) for x in cf_trace]
    plot(t_ownship, h_crash,
        labels="Ownship (current advisory)",
        linestyle=:solid,
        legend=:outertopright,
        xlims=xlims, ylims=ylims,
        xlabel="time for intruder / -time for ownship (s)",
        ylabel="altitude (ft)",
        size=figsize,
        leftmargin = 30Plots.px,
        bottommargin = 40Plots.px,
        color=:blue, linewidth=3,
        tickfontsize=16,
        guidefontsize=16,
        legendfontsize=16)#,
        #aspect_ratio=3e-3)
    plot!(t_ownship, h_cf, labels="Original path of ownship",linestyle=:dash,color=:orange, linewidth=3)
    plot!(t_intruder,h_intruder, label="Intruder",color=:purple,linestyle=:dot, linewidth=3)
    plot!(nmac_rectangle(altitute_offset=h_intruder_nmac),fopacity=.3,label="NMAC",color=:red)

    # Images
    if show_planes
        y_modifier = (ylims[2]-ylims[1])/max(xlims[2],-xlims[1])
        # Ownship
        # Compute angle
        dt = delta#tau
        dh = (h_crash[convert(Int,delta/tau)][1]-h_crash[1][1])/y_modifier
        println(dh*180/pi)
        println(dt)
        println(dh)
        theta = atan(dh/dt)
        ownship = imrotate(reverse(intruder,dims=(1,2)),theta)
        x1 = -time_to_nmac
        x2 = -time_to_nmac+delta*(size(ownship,2)/size(intruder,2))
        ownship_ratio = size(ownship,1)/size(ownship,2)
        y_range = (x2-x1)*ownship_ratio*y_modifier*imgmodifier
        if theta > 0
            y1 = h_crash[1]-y_range*(1/8)
            y2 = h_crash[1]+y_range*(7/8)
        else
            y1 = h_crash[1]-y_range*(7/8)
            y2 = h_crash[1]+y_range*(1/8)
        end
        plot!([x1,x2],[y1,y2],ownship,fopacity=1.0,aspect_ratio=:none,yflip=false)
        # Intruder
        x1 = time_to_nmac-delta
        x2 = time_to_nmac
        intruder_ratio = size(intruder,1)/size(intruder,2)
        y_range = (x2-x1)*intruder_ratio*y_modifier*imgmodifier
        y1 = pos_intruder-y_range*(4/8)
        y2 = pos_intruder+y_range*(4/8)
        plot!([x1,x2],[y1,y2],reverse(intruder,dims=1),fopacity=1.0,aspect_ratio=:none,yflip=false)
    end
    #xlims=xlims, ylims=ylims,size=figsize)
    #plot!([-7.0,7.0],[9400,11000])
    savefig(plot_name)
end