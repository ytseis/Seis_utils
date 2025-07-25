using Seis, CairoMakie

function _line_and_scatter!(ax, x, y; linesargs=(), scatterargs=())
    lines!(ax, x, y; linesargs...)
    scatter!(ax, x, y; scatterargs...)
end

# TODO: Radial and transverse hodograms
"""
    hodograms_3comp(st::AbstractArray{<:AbstractTrace}, t1, t2; color=true)
Generate hodogram plots for three-component seismic data.
- `st`: Seismic trace data (3-component).
- `t1`, `t2`: Time window for the plots.
- `color`: If true, uses color coding for time information in waveforms.
"""
function hodograms_3comp(st::AbstractArray{<:AbstractTrace}, t1, t2; color=true)
    # Unit definitions for plot sizing
    inch = 96
    pt = 4/3
    cm = inch / 2.54

    # Cut seismic traces to specified time window
    stc = cut.(st, t1, t2)

    # Create figure with 2x2 subplot layout
    fig = Figure(size=(16cm, 16cm), fontsize=10pt)

    # Define axes for waveform display and hodogram plots
    ax_wf = Axis(fig[1,1],
        xlabel="Time / s", ylabel="",
        aspect=1,
        xminorticksvisible=true, yminorticksvisible=false,
        xticks = LinearTicks(3),
        yticks=(-1:1, ["E", "N", "U"]),
    )
    hideydecorations!(ax_wf, ticklabels=false)
    hlines!(ax_wf, -1:1, color=:lightgray, linestyle=:dot)
    hlines!(ax_wf, -.5:.5, color=:gray)

    ax_ne = Axis(fig[1,2],
        xlabel="E", ylabel="N",
        aspect=1,
        xminorticksvisible=true, yminorticksvisible=true,
        xtickformat="{:.0e}",
        ytickformat="{:.0e}",
        xticks = LinearTicks(4),
        yticks = LinearTicks(4),
    )
    ax_un = Axis(fig[2,1],
        xlabel="N", ylabel="U",
        aspect=1,
        xminorticksvisible=true, yminorticksvisible=true,
        xtickformat="{:.0e}",
        ytickformat="{:.0e}",
        xticks = LinearTicks(4),
        yticks = LinearTicks(4),
    )
    ax_ue = Axis(fig[2,2],
        xlabel="E", ylabel="U",
        aspect=1,
        xminorticksvisible=true, yminorticksvisible=true,
        xtickformat="{:.0e}",
        ytickformat="{:.0e}",
        xticks = LinearTicks(4),
        yticks = LinearTicks(4),
    )

    # Extract N, E, U components from seismic data
    trn = filter(tr -> occursin("N", tr.sta.cha), stc) |> first  # NS component
    tre = filter(tr -> occursin("E", tr.sta.cha), stc) |> first  # EW component
    tru = filter(tr -> tr!==trn&&tr!==tre, stc) |> first         # UD component

    # Calculate maximum amplitudes for normalization
    max_amp = maximum([
        maximum(abs, trace(tru)),
        maximum(abs, trace(trn)),
        maximum(abs, trace(tre))
    ])*1.05

    # Plot normalized waveforms (U at +1, N at 0, E at -1)
    if color
        # Color-coded time information for waveforms
        c = ColorScheme(get(ColorSchemes.rainbow, range(0.0, 1.0, length=nsamples(tru))))
        for (tr, offset) in zip([tru, trn, tre], [1, 0, -1])
            linesargs = (color=:gray,)
            scatterargs = (color=:transparent,
                markersize=4pt, strokewidth=1pt, strokecolor=c.colors
            )
            # _line_and_scatter!(ax_wf, times(tr), trace(tr)/max_amp/2 .+ offset,
            #     linesargs=linesargs, scatterargs=scatterargs
            # )
            # lines on scatter
            scatter!(ax_wf, times(tr), trace(tr)/max_amp/2 .+ offset,
                color=:transparent, markersize=4pt, strokecolor=c.colors,
                strokewidth=1pt
            )
            lines!(ax_wf, times(tr), trace(tr)/max_amp/2 .+ offset,
                color=:black
            )
        end
    else
        # Monochrome version without color coding
        ax_x_y = zip([ax_wf, ax_wf, ax_wf], [times(tru), times(trn), times(tre)],
            [trace(tru)/max_amp/2 .+ 1, trace(trn)/max_amp/2 .+ 0, trace(tre)/max_amp/2 .- 1])
        for (ax, x, y) in ax_x_y
            lines!(ax, x, y, color=:black)
        end
    end

    # Set time limits for waveform plot
    xlims!(ax_wf, t1, t2)
    ylims!(ax_wf, -1.5, 1.5)

    # Plot hodograms (particle motion plots)
    if color
        # Configure arguments for line and scatter plots
        ax_tr_x_tr_y = [
            (ax_ne, tre, trn),
            (ax_un, trn, tru),
            (ax_ue, tre, tru)
        ]
        for (ax, tr_x, tr_y) in ax_tr_x_tr_y
            c = ColorScheme(get(ColorSchemes.rainbow, range(0.0, 1.0, length=nsamples(tr_x))))
            _line_and_scatter!(ax, trace(tr_x), trace(tr_y);
                linesargs=(color=:gray,),
                scatterargs=(color=:transparent,
                    markersize=4pt, strokewidth=1pt, strokecolor=c.colors
                )
            )
        end
    else
        # Simple black lines for monochrome version
        # ax_x_y = zip([ax_ne, ax_un, ax_ue], [trace(tre), trace(trn), trace(tru)],
        #     [trace(trn), trace(tru), trace(tre)])
        ax_x_y = [
            (ax_ne, trace(tre), trace(trn)),
            (ax_un, trace(trn), trace(tru)),
            (ax_ue, trace(tre), trace(tru))
        ]
        for (ax, x, y) in ax_x_y
            lines!(ax, x, y, color=:black)
        end
    end

    # Set symmetric axis limits for hodogram plots
    xlims!.([ax_ne, ax_un, ax_ue], -max_amp, max_amp)
    ylims!.([ax_ne, ax_un, ax_ue], -max_amp, max_amp)

    # Create station identifier for plot title
    id = split(channel_code(st[1]), ".")
    id = filter(x -> !isempty(x), id)
    id = if length(id) == 2
        id[1]
    else
        join(id[1:2], ".")
    end

    # Add title label
    Label(fig[0,1:end], text=id,
        tellwidth=false, tellheight=false, fontsize=16pt
    )

    # Set equal spacing for subplot layout
    for i in 1:2
        rowsize!(fig.layout, i, Relative(.5))
        colsize!(fig.layout, i, Relative(.5))
    end

    return fig
end
