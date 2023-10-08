object "Example" {
  code {
    datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
    return(0, datasize("Runtime"))
    // storage layout.
  }
  object "Runtime" {
    // Return the calldata
    code {
      // set up free memory pointer
      // we need function selector... switch statement.
      mstore(0x80, calldataload(0))
      return(0x80, calldatasize())
    }
  }
}