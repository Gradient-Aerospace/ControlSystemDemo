## Imports
import HDF5Vectors # Allows us to use the HDF5-based log.
# using SystemsOfSystemsHDF5Logs: HDF5LogOptions, load_hdf5_log # <- An alternative to the extension approach used by the above.
using SystemsOfSystems: simulate, SimOptions, Logs, Solvers, Monitors, TimeSeries, plot_ts,
    load_hdf5_log, gather_all_time_series
import GLMakie # For the plots

## Models
include("models.jl")

# Set the parameters for all of the models.
system_specs = ClosedLoopSystemSpecs(
    plant = PlantSpecs(
        mass = 1.,
        initial_position = 0.,
        initial_velocity = 0.,
    ),
    sensor = SensorSpecs(
        dt = 0.1,
        sigma_noise = 0.,
        sigma_bias = 0.,
    ),
    target = ConstantTargetSpecs(
        constant_position = 1.,
    ),
    controller = PDControllerSpecs(
        dt = 0.1,
        p = 8.,
        d = 4.,
        initial_position = 0.,
        initial_command = 0.,
    ),
    actuator = ActuatorSpecs(
        time_constant = 0.2,
        initial_command = 0.,
        initial_response = 0.,
    ),
)

## Sim Run

# Get a clean output directory ready.
out_dir = "out"
log_file = "$out_dir/history.h5"
if isdir(out_dir); rm(out_dir; recursive = true); end

# Run the sim.
history, t, system = simulate(
    system_specs;
    init_fcn = init, # calls model_description = init_fcn(t, system_description, rng)
    rates_fcn = rates, # calls rates_fcn(t, system_model)
    updates_fcn = updates, # calls updates_fcn(t, system_model)
    t = (0, 10),
    options = SimOptions(;
        log = Logs.HDF5LogOptions(log_file),
        # log = nothing,
        # solver = Solvers.RungeKutta4Options(; dt = 1//10),
        solver = Solvers.DormandPrince54Options(),
        monitors = [Monitors.ProgressBarOptions(),],
        # time_dimension = "Time" => "hours",
    ),
)
# # Logs.close_log(history.log) # So we can open the file anew.
# @time history, t, system = simulate(
#     system_specs;
#     init_fcn = init, # calls model_description = init_fcn(t, system_description, rng)
#     rates_fcn = rates, # calls rates_fcn(t, system_model)
#     updates_fcn = updates, # calls updates_fcn(t, system_model)
#     t = (0, 1000),
#     options = SimOptions(;
#         # log = Logs.HDF5LogOptions(log_file),
#         solver = Solvers.RungeKutta4Options(; dt = 1//10),
#         # solver = Solvers.DormandPrince54Options(),
#         monitors = [Monitors.ProgressBarOptions(),],
#         # time_dimension = "Time" => "hours",
#     ),
# )

if t == 0
    exit()
end

## Analysis

@show t
display(system)

display(history)
display(history["/plant"])
display(history["/plant"].continuous_states.position)
display(history["/plant"]["position"])

## And we can re-load it here like so:
# log, _ = load_hdf5_log(log_file);

## Plots

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

# Display and save everything.
for (path, p) in plots
    f = plot_ts(p)
    display(GLMakie.Screen(), f)
    filename = out_dir * "/" * replace(path, r":" => "/"; count = 1) * ".png"
    mkpath(dirname(filename))
    GLMakie.save(filename, f)
end

# Now save a single HDF5 file with alphas and the array of file names.

## outputs.h5:
#   
# /timeseries/control_error
#                          /title
#                          /time
#                          /data
#                          /time_label
#                          /time_units
#                          /labels
#                          /units
# /models/plant/timeseries/position
#                                  /metadata
#                                      /title
#                                      /labels
#                                      /units
#                                  /t
#                                  /data
# /models/plant/timeseries/forces
#                                /metadata
#                                    /title
#                                    /labels
#                                    /units
#                                /t
#                                /data
# /models/actuator/timeseries/response
#                                     /metadata
#                                         /title
#                                         /labels
#                                         /units
#                                     /t
#                                     /data

## Over in MATLAB...
#
# plot_ts("outputs.h5", "/plant/position")
#
# plot_ts("outputs.h5", "/plant/forces")

