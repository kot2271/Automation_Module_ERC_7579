import { createKernelAccount, createKernelAccountClient, createZeroDevPaymasterClient } from "@zerodev/sdk"
import { signerToEcdsaValidator } from "@zerodev/ecdsa-validator"
import { http, createPublicClient, zeroAddress } from "viem"
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts"
import { sepolia } from "viem/chains"
import { ENTRYPOINT_ADDRESS_V07, bundlerActions } from "permissionless"
 
const PROJECT_ID = '98fd43a8-fb2f-4948-a7ae-069f53969f73'
const BUNDLER_RPC = `https://rpc.zerodev.app/api/v2/bundler/${PROJECT_ID}`
const PAYMASTER_RPC = `https://rpc.zerodev.app/api/v2/paymaster/${PROJECT_ID}`
 
const chain = sepolia
const entryPoint = ENTRYPOINT_ADDRESS_V07
 
const main = async () => {
  // Construct a signer
  const privateKey = generatePrivateKey()
  const signer = privateKeyToAccount(privateKey)
 
  // Construct a public client
  const publicClient = createPublicClient({
    transport: http(BUNDLER_RPC),
  })
 
  // Construct a validator
  const ecdsaValidator = await signerToEcdsaValidator(publicClient, {
    signer,
    entryPoint,
  })
 
  // Construct a Kernel account
  const account = await createKernelAccount(publicClient, {
    plugins: {
      sudo: ecdsaValidator,
    },
    entryPoint,
  })
 
  // Construct a Kernel account client
  const kernelClient = createKernelAccountClient({
    account,
    chain,
    entryPoint,
    bundlerTransport: http(BUNDLER_RPC),
    middleware: {
      sponsorUserOperation: async ({ userOperation }) => {
        const zerodevPaymaster = createZeroDevPaymasterClient({
          chain,
          entryPoint,
          transport: http(PAYMASTER_RPC),
        })
        return zerodevPaymaster.sponsorUserOperation({
          userOperation,
          entryPoint,
        })
      },
    },
  })
 
  const accountAddress = kernelClient.account.address
  console.log("My account:", accountAddress)
 
  // Send a UserOp
  const userOpHash = await kernelClient.sendUserOperation({
    userOperation: {
      callData: await kernelClient.account.encodeCallData({
        to: zeroAddress,
        value: BigInt(0),
        data: "0x",
      }),
    },
  })
 
  console.log("UserOp hash:", userOpHash)
  console.log("Waiting for UserOp to complete...")
 
  const bundlerClient = kernelClient.extend(bundlerActions(entryPoint));
  await bundlerClient.waitForUserOperationReceipt({
    hash: userOpHash,
  })
 
  console.log("View completed UserOp here: https://jiffyscan.xyz/userOpHash/" + userOpHash)
}
 
main()