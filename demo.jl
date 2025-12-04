## Imports
import HDF5Vectors # Allows us to use the HDF5-based log.
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
mkpath(out_dir)

# Run the sim.
history, t, system = simulate(
    system_specs; # Parameters used to create models
    init_fcn = init, # Returns a description of the models
    rates_fcn = rates, # Returns the rate of change of continuous states
    updates_fcn = updates, # Returns the updates for the discrete states
    t = (0, 10), # Start and end times (or a whole vector of times)
    options = SimOptions(;
        log = Logs.HDF5LogOptions(log_file), # Logs results to portable HDF5 file.
        monitors = [Monitors.ProgressBarOptions(),], # Show a progress bar while running.
        time_dimension = "Time" => "hours", # Tell it that time has units of seconds here.
    ),
)

# If it didn't finish, bail.
if t == 0
    exit()
end

## Analysis

# Show the final state of the system.
display(system)

# Check out what's in "history".
display(history)

# See what a single model's time history looks like.
display(history["/plant"])

# Check out its "position" variable's time series.
display(history["/plant"]["position"])

## And we can re-load the log from the HDF5 later like so:
# log, _ = load_hdf5_log(log_file);

## Plots

# Make a whole catalog of plots.
plots = Pair[
    # We'll add two custom plots that combine various time series from the histories.
    "true position vs target" => [
        "truth" => history["/plant"]["position"],
        "target" => history["/target"]["target"],
    ],
    "actuator command vs response" => [
        "command" => history["/actuator"]["command"],
        "response" => history["/actuator"]["response"],
    ],
    # And let's also add every single time series from the sim into this list.
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

## Analysis Outside Julia
#  
# outputs.h5:
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

