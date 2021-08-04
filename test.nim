
template hello(Ts: varargs[typedesc]) =
    echo Ts.len

hello(float, int, string)