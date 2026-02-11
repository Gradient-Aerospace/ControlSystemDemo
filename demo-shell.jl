# Include the stuff we'll need.
import HDF5Vectors # Allows us to use the HDF5-based log.
using SystemsOfSystems: simulate, SimOptions, Logs, Solvers, Monitors, Dimension,
    plot_ts, gather_all_time_series
using PortableStructs: load_from_yaml, write_to_yaml
import GLMakie # A plotting package

# Include our own models.
include("models.jl")

# We'll create a type that the input file is supposed to map to.
@kwdef struct Inputs
    time::Vector{Float64}
    options::SimOptions
    system::ClosedLoopSystemSpecs
end

# Create a CLI argument parser.
using ArgParse
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--input", "-i"
            help = "a YAML input file"
            arg_type = String
        "--output", "-o"
            help = "the desired output directory"
            arg_type = String
    end
    return parse_args(s)
end

# Parse the command-line options to get the input and output file names.
parsed_args = parse_commandline()
input_file = parsed_args["input"]
out_dir = parsed_args["output"]

# Parse the inputs argument as the type we need.
inputs = load_from_yaml(input_file, Inputs)

# Get the output directory ready.
mkpath(out_dir)

# We can also write out our inputs to YAML. Let's add those to the output directory.
write_to_yaml(joinpath(out_dir, "inputs.yaml"), inputs)

# Run the simulation, saving the outputs to the given directory.
history, t, system = simulate(
    inputs.system;
    init_fcn = init,
    rates_fcn = rates,
    updates_fcn = updates,
    t = inputs.time,
    options = inputs.options,
)

# Make a whole catalog of plots, starting with these two custom plots.
plots = Pair[
    "true position vs target" => [
        "truth" => history["/plant"]["position"],
        "target" => history["/target"]["target"],
    ],
    "actuator command vs response" => [
        "command" => history["/actuator"]["command"],
        "response" => history["/actuator"]["response"],
    ],
    pairs(gather_all_time_series(history.log))...,
]

# Save everything.
for (path, p) in plots
    f = plot_ts(p)
    filename = replace(path, r":" => "/"; count = 1) * ".png"
    if startswith(filename, "/")
        filename = filename[2:end]
    end
    filename = joinpath(out_dir, filename)
    mkpath(dirname(filename))
    GLMakie.save(filename, f)
end
