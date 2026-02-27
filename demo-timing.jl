## Imports
import HDF5Vectors # Allows us to use the HDF5-based log.
# using SystemsOfSystemsHDF5Logs: HDF5LogOptions, load_hdf5_log # <- An alternative to the extension approach used by the above.
using SystemsOfSystems: simulate, SimOptions, Logs, Solvers, Monitors
# import GLMakie # For the plots

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

## Let's see how our own functions allocate.

using SystemsOfSystems
using Random

t = 0//1
rng = Xoshiro(1)
md = init(t, system_specs, rng)
ommd = SystemsOfSystems.strip_fluff_from_model_description(md)
msd = SystemsOfSystems.draw_wd(t, ommd, ommd)
system = SystemsOfSystems.model(msd)

@show isbits(msd)

rates(t, system)
@time rates(t, system)

println("updates")
updates(t, system)
@time updates(t, system)

## Sim core functions

using InteractiveUtils

# SystemsOfSystems.find_soonest_t_next(1//1, msd)
# t_array = Vector{Rational{Int64}}(undef, 1)
# function baz!(msd, t_array)
#     t_array[1] = SystemsOfSystems.find_soonest_t_next(1//1, msd)
# end
# baz!(msd, t_array)
# @time baz!(msd, t_array)

println("update")
updates_output = updates(t, system)
SystemsOfSystems.update(msd, updates_output)
@time SystemsOfSystems.update(msd, updates_output)
# @code_warntype SystemsOfSystems.update(msd, updates_output)

println("propagate")
rates_output = rates(t, system)
SystemsOfSystems.Solvers.propagate(msd, 1//1, rates_output)
@time SystemsOfSystems.Solvers.propagate(msd, 1//1, rates_output)
# @code_warntype SystemsOfSystems.Solvers.propagate(msd, 1//1, rates_output)

println("propagate2")
rates_output = rates(t, system)
SystemsOfSystems.Solvers.propagate(msd, (1//1, 1//1), (rates_output, rates_output))
@time SystemsOfSystems.Solvers.propagate(msd, (1//1, 1//1), (rates_output, rates_output))

## Sim Run

# Get a clean output directory ready.
out_dir = "out-timing"
log_file = "$out_dir/history.h5"
mkpath(out_dir)

function run_sim(t_end)
    return simulate(
        system_specs;
        init_fcn = init, # calls model_description = init_fcn(t, system_description, rng)
        rates_fcn = rates, # calls rates_fcn(t, system_model)
        updates_fcn = updates, # calls updates_fcn(t, system_model)
        t = (0, t_end),
        options = SimOptions(;
            # log = Logs.HDF5LogOptions(log_file),
            # log = nothing,
            # solver = Solvers.RungeKutta4Options(; dt = 1//10),
            # solver = Solvers.DormandPrince54Options(),
            # monitors = [Monitors.ProgressBarOptions(),],
            # time_dimension = "Time" => "hours",
        ),
    )
end

# Run the sim.
# history, t, system = run_sim(10)
history, t, system = run_sim(1)
Logs.close_log(history.log)
println("Timing run:")
@time history, t, system = run_sim(1)
Logs.close_log(history.log)
@time history, t, system = run_sim(100)
Logs.close_log(history.log)
@time history, t, system = run_sim(1000)
Logs.close_log(history.log)
