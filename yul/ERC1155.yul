object "ERC1155" {
  code {
    sstore(0, caller()) // Store the creator in slot zero
    datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
    return(0, datasize("Runtime"))
  }
  object "Runtime" {
    code {
      require(iszero(callvalue()))

      switch selector()
      case 0x156e29f6 /* mint(address,token_id,uint256) */ { 
        mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
        returnTrue()
      }
      case 0x00fdd58e /* balanceOf(address,uint256) */ {
        returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
      }
      case 0xa22cb465 /* setApprovalForAll(address,bool) */ {
        setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
        returnTrue()
      }
      case 0xe985e9c5 /* isApprovedForAll(address,address) */ {
        returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))
      }
      case 0xf242432a /* safeTransferFrom(address,address,uint256,uint256,bytes) */ {
        safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3))
        returnTrue()
      }
      case 0x4e1273f4 /* balanceOfBatch(address[],uint256[]) */ {
        balanceOfBatch()
      }
      case 0x2eb2c2d6 /* safeBatchTransferFrom(address,address,uint256[],uint256[],bytes) */ {
        safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1))
      }
      default { revert(0, 0) }

      function mint(to, token_id, amount) {
          require(calledByOwner())
          addToBalance(to, token_id, amount)
      }

      function setApprovalForAll(spender, approved) {
          sstore(allowanceStorageOffset(caller(), spender), approved)
      }

      function isApprovedForAll(account, spender) -> r {
          r := eq(sload(allowanceStorageOffset(account, spender)), 1)
      }

      function safeBatchTransferFrom(from, to) {
        revertIfZeroAddress(to)
        if iszero(or(eq(from, caller()), isApprovedForAll(from, caller()))) {
            revert(0, 0) // caller is not `from` nor approved for all
        }

        let ids_ptr := add(0x04, calldataload(0x44))
        let values_ptr := add(0x04, calldataload(0x64))
        let ids_len := calldataload(ids_ptr)
        let values_len := calldataload(values_ptr)

        // if arrays are not same length revert
        if iszero(eq(ids_len, values_len)) {
          revert(0, 0)
        }

        // advance pointers over lengths, onto actual data
        ids_ptr := add(ids_ptr, 0x20)
        values_ptr := add(values_ptr, 0x20)

        // loop over arrays, reading from storage and writing to memory
        for { let i := 0 } lt(i, ids_len) { i := add(i, 1) } {
          let id := calldataload(ids_ptr)
          let value := calldataload(values_ptr)
          deductFromBalance(from, id, value)
          addToBalance(to, id, value)
          ids_ptr := add(ids_ptr, 0x20)
          values_ptr := add(values_ptr, 0x20)
        }
      }

      function balanceOfBatch() {
        let addrs_ptr := add(0x04, calldataload(0x04))
        let ids_ptr := add(0x04, calldataload(0x24))
        let addrs_len := calldataload(addrs_ptr)
        let ids_len := calldataload(ids_ptr)

        // if arrays are not same length revert
        if iszero(eq(addrs_len, ids_len)) {
          revert(0, 0) 
        }

        // advance pointers over lengths, onto actual data
        addrs_ptr := add(addrs_ptr, 0x20)
        ids_ptr := add(ids_ptr, 0x20)

        // loop over arrays, reading from storage and writing to memory
        for { let i := 0 } lt(i, addrs_len) { i := add(i, 1) } {
          let addr := calldataload(addrs_ptr)
          let id := calldataload(ids_ptr)
          let bal := balanceOf(addr, id)
          mstore(add(0x40, mul(i, 0x20)), bal)
          addrs_ptr := add(addrs_ptr, 0x20)
          ids_ptr := add(ids_ptr, 0x20)
        }

        // return pointer, length, and array items
        mstore(0x00, 0x20)
        mstore(0x20, addrs_len)
        return(0x00, add(0x40, mul(addrs_len, 0x20)))
      }

      function safeTransferFrom(from, to, token_id, amount) {
        if iszero(or(eq(from, caller()), isApprovedForAll(from, caller()))) {
            revert(0, 0) // caller is not `from` nor approved for all
        }

        revertIfZeroAddress(from)
        revertIfZeroAddress(to)
        deductFromBalance(from, token_id, amount)
        addToBalance(to, token_id, amount)
        emitTransferSingle(caller(), from, to, token_id, amount)

        // call function on recipient!
        // write bytes to memory?? needed for the hook...
        let start_pos := add(4, mul(4, 0x20)) // get the start position
        let len := calldataload(start_pos) // number of bytes from start pos
        let pos := add(start_pos, 0x20) // skip over length
        for { let i := 0 } lt(i, len) { i := add(i, 1) } {
            let offset := add(pos, i)
            let v := calldataload(offset)
            mstore8(add(0x00, i), byte(0, v))
        }
      }

      /* ---------- calldata decoding functions ----------- */
      function selector() -> s {
          s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function decodeAsAddress(offset) -> v {
          v := decodeAsUint(offset)
          if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
              revert(0, 0) // does this ever happen? 
          }
      }
      function decodeAsUint(offset) -> v {
          let pos := add(4, mul(offset, 0x20)) // skip over selector bytes
          if lt(calldatasize(), add(pos, 0x20)) {
              revert(0, 0) // out of bounds
          }
          v := calldataload(pos) // load 32 bytes from pos
      }

      /* ---------- calldata encoding functions ---------- */
      function returnUint(v) {
          mstore(0, v)
          return(0, 0x20)
      }
      function returnTrue() {
          returnUint(1)
      }

      /* -------- events ---------- */
      function emitTransferSingle(operator, from, to, token_id, amount) {
          let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
          emitEvent(signatureHash, operator, from, to, token_id, amount)
      }
      // function emitTransferBatch(operator, from, to) {
      //     let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
      //     mstore(0, nonIndexed1)
      //     mstore(0x20, nonIndexed2)
      //     log4(0, 0x40, signatureHash, indexed1, indexed2, indexed3)
      // }
      // function emitApprovalForAll(operator, from, to, ids, values) {
      //     let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
      //     mstore(0, nonIndexed1)
      //     mstore(0x20, nonIndexed2)
      //     log4(0, 0x40, signatureHash, indexed1, indexed2, indexed3)
      // }
      function emitEvent(signatureHash, indexed1, indexed2, indexed3, nonIndexed1, nonIndexed2) {
          mstore(0, nonIndexed1)
          mstore(0x20, nonIndexed2)
          log4(0, 0x40, signatureHash, indexed1, indexed2, indexed3)
      }

      /* -------- storage layout ---------- */
      function ownerPos() -> p { p := 0 }
      function balanceOfStorageOffset(account, token_id) -> offset {
          // hash(account, token_id)
          mstore(0, account)
          mstore(0x20, token_id)
          offset := keccak256(0, 0x40)
      }
      function allowanceStorageOffset(account, spender) -> offset {
          // hash(account + 1,  spender)
          offset := add(0x1, account)
          mstore(0, offset)
          mstore(0x20, spender)
          offset := keccak256(0, 0x40)
      }

      /* -------- storage access ---------- */
      function owner() -> o {
          o := sload(ownerPos())
      }
      function balanceOf(account, token_id) -> bal {
          bal := sload(balanceOfStorageOffset(account, token_id))
      }
      function addToBalance(account, token_id, amount) {
          let offset := balanceOfStorageOffset(account, token_id)
          sstore(offset, safeAdd(sload(offset), amount))
      }
      function deductFromBalance(account, token_id, amount) {
          let offset := balanceOfStorageOffset(account, token_id)
          let bal := sload(offset)
          require(lte(amount, bal))
          sstore(offset, sub(bal, amount))
      }

      /* ---------- utility functions ---------- */
      function lte(a, b) -> r {
          r := iszero(gt(a, b))
      }
      function gte(a, b) -> r {
          r := iszero(lt(a, b))
      }
      function safeAdd(a, b) -> r {
          r := add(a, b)
          if or(lt(r, a), lt(r, b)) { revert(0, 0) }
      }
      function calledByOwner() -> cbo {
          cbo := eq(owner(), caller())
      }
      function revertIfZeroAddress(addr) {
          require(addr)
      }
      function require(condition) {
          if iszero(condition) { revert(0, 0) }
      }
    }
  }
}
