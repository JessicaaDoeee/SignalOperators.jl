using Unitful
export mapsignal, mix, amplify, addchannel

################################################################################
# binary operators

struct SignalOp{Fn,Fs,El,L,S,A,Args,Pd} <: AbstractSignal
    fn::Fn
    val::El
    len::L
    state::S
    samples::A
    samplerate::Fs
    args::Args
    padding::Pd
end
struct NoValues
end
novalues = NoValues()
SignalTrait(x::Type{<:SignalOp{<:Any,Fs,El,L}}) where {Fs,El,L} = IsSignal{El,Fs,L}()
nsamples(x::SignalOp) = x.len
nchannels(x::SignalOp) = length(x.state)
samplerate(x::SignalOp) = x.samplerate
function tosamplerate(x::SignalOp,s::IsSignal,c::ComputedSignal,fs)
    if ismissing(x.samplerate) || ismissing(fs) || fs < x.samplerate
        # resample input if we are downsampling 
        mapsignal(x.fn,tosamplerate.(x.args,fs)...,padding=x.padding)
    else
        # resample output if we are upsampling
        tosamplerate(x,s,DataSignal(),fs)
    end
end

function mapsignal(fn,xs...;padding = default_pad(fn),across_channels = false)
    xs = uniform(xs)   
    fs = samplerate(xs[1])
    finite = findall(!infsignal,xs)
    if !isempty(finite)
        if any(@λ(!=(xs[finite[1]],_)),xs[finite[2:end]])
            longest = argmax(map(i -> nsamples(xs[i]),finite))
            xs = (map(pad(padding),xs[1:longest-1])..., xs[longest],
                  map(pad(padding),xs[longest+1:end])...)
            len = nsamples(xs[longest])
        else
            len = nsamples(xs[finite[1]])
        end
    else
        len = nothing
    end
    sm = samples.(xs)
    results = iterate.(sm)
    if any(isnothing,results)
        SignalOp(fn,novalues,len,(true,nothing),sm,fs)
    else
        if !across_channels
            fnbr(vals...) = fn.(vals...)
            vals = map(@λ(_[1]),results)
            y = astuple(fnbr(vals...))
            SignalOp(fnbr,y,len,(true,map(@λ(_[2]),results)),sm,xs,fs)
        else
            vals = map(@λ(_[1]),results)
            y = astuple(fn(vals...))
            SignalOp(fn,y,len,(true,map(@λ(_[2]),results)),sm,xs,fs,padding)
        end
    end
end

Base.iterate(x::SignalOp{<:Any,NoValues}) = nothing
function Base.iterate(x::SignalOp,(use_val,states) = x.state)
    if use_val
        x.val, (false,states)
    else
        results = iterate.(x.samples,states)
        if any(isnothing,results)
            nothing
        else
            vals = map(@λ(_[1]),results)
            astuple(x.fn(vals...)), (false,map(@λ(_[2]),results))
        end
    end
end

default_pad(x) = zero
default_pad(::typeof(+)) = zero
default_pad(::typeof(*)) = one
default_pad(::typeof(-)) = zero
default_pad(::typeof(/)) = one

mix(x) = y -> mix(x,y)
mix(xs...) = mapsignal(+,xs...)

amplify(x) = y -> amplify(x,y)
amplify(xs...) = mapsignal(*,xs...)

addchannel(y) = x -> addchannel(x,y)
addchannel(xs...) = mapsignal(tuplecat,xs...;across_channels=true)
tuplecat(a,b) = (a...,b...)
tuplecat(a,b,c,rest...) = reduce(tuplecat,(a,b,c,rest...))

channel(n) = x -> channel(x,n)
channel(x,n) = mapsignal(@λ(_[1]), x,across_channels=true)
