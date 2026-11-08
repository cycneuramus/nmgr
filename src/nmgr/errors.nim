type
  NmgrError* = object of CatchableError
  ConfigError* = object of NmgrError
  JobError* = object of NmgrError
  NomadError* = object of NmgrError
  TargetError* = object of NmgrError
