
--define:debug
--gc:arc
--define:useMalloc
--threads:on
--styleCheck:hint
--passL:"-static"

task default, "default compile":
    setCommand "c"