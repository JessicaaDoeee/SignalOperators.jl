
export rampon, rampoff, ramp, fadeto

function rampon_fn(x,len,fun)
    time = inseconds(Float64,len,samplerate(x))
    x -> x ≤ time ? fun(x/time) : 1.0
end

sinramp(x) = sinpi(0.5x)
rampon(fun::Function) = rampon(10ms,fun)
rampon(len::Number=10ms,fun::Function=sinramp) = x -> rampon(x,len,fun)
function rampon(x,len::Number=10ms,fun::Function=sinramp)
    x = signal(x)
    signal(rampon_fn(x,len,fun),samplerate(x)) |> amplify(x)
end

function rampoff_fn(x,len,fun)
    time = inseconds(Float64,len,samplerate(x))
    ramp_start = duration(x) - time
    if ismissing(ramp_start)
        error("Uknown signal duration: cannot determine rampoff parameters. ",
              "Define the samplerate or signal length earlier in the ",
              "processing chain.")
    end
    x -> x < ramp_start ? 1.0 : fun(1.0 - (x-ramp_start)/time)
end

rampoff(fun::Function) = rampoff(10ms,fun)
rampoff(len::Number=10ms,fun::Function=sinramp) = x -> rampoff(x,len,fun)
function rampoff(x,len::Number=10ms,fun::Function=sinramp)
    x = signal(x)
    signal(rampoff_fn(x,len,fun),samplerate(x)) |> amplify(x)
end

ramp(fun::Function) = ramp(10ms,fun)
ramp(len::Number=10ms,fun::Function=sinramp) = x -> ramp(x,len,fun)
function ramp(x,len::Number=10ms,fun::Function=sinramp)
    x = signal(x)
    x |> rampon(len,fun) |> rampoff(len,fun)
end

fadeto(y,fun::Function) = fadeto(y,10ms,fun)
fadeto(y,len::Number=10ms,fun::Function=sinramp) = x -> fadeto(x,y,len,fun)
function fadeto(x,y,len::Number=10ms,fun::Function=sinramp)
    x,y = uniform((x,y))
    x = signal(x)
    n = insamples(Int,maybeseconds(len),samplerate(x))
    silence = signal(zero(channel_eltype(y))) |> until((nsamples(x) - n)*samples)
    x |> rampoff(len,fun) |> mix(
        y |> rampon(len,fun) |> prepend(silence))
end
