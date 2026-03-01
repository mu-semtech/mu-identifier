defmodule JwtToken do
  @moduledoc """
  Encodes and decodes mu session tokens as signed JWTs (JWS) with an
  encrypted private claim (JWE).
  """

  def encode(expires_at, private_claims) do
    private_blob = encrypt_private(private_claims)
    public_claims =
      if expires_at do
        %{"private" => private_blob, "exp" => expires_at}
      else
        %{"private" => private_blob}
      end

    {_, compact_token} =
      JOSE.JWT.sign(jwt_sign_key(), %{"alg" => "HS256"}, public_claims)
      |> JOSE.JWS.compact()

    compact_token
  end

  def decode(token) do
    case JOSE.JWT.verify(jwt_sign_key(), token) do
      {true, %JOSE.JWT{fields: public_claims}, _jws} ->
        case decrypt_private(Map.get(public_claims, "private")) do
          {:ok, private_claims} -> {:ok, {public_claims, private_claims}}
          error -> error
        end

      {false, _, _} ->
        {:error, :invalid}
    end
  rescue
    _ -> {:error, :malformed}
  end

  defp encrypt_private(private_claims) do
    {_, compact_jwe} =
      JOSE.JWE.block_encrypt(
        jwt_encrypt_key(),
        Jason.encode!(private_claims),
        %{"alg" => "dir", "enc" => "A256GCM"}
      )
      |> JOSE.JWE.compact()

    compact_jwe
  end

  defp decrypt_private(nil), do: {:error, :malformed}
  defp decrypt_private(compact_jwe) do
    {plaintext, _jwe} = JOSE.JWE.block_decrypt(jwt_encrypt_key(), compact_jwe)
    Jason.decode(plaintext)
  rescue
    _ -> {:error, :malformed}
  end

  defp jwt_sign_key do
    case :persistent_term.get(:mu_identifier_jwt_sign_key, nil) do
      nil ->
        key = :crypto.mac(:hmac, :sha256, Secret.secret_key_base(), Proxy.signing_salt() <> "-signing")
        jwk = JOSE.JWK.from_oct(key)
        :persistent_term.put(:mu_identifier_jwt_sign_key, jwk)
        jwk
      jwk -> jwk
    end
  end

  defp jwt_encrypt_key do
    case :persistent_term.get(:mu_identifier_jwt_encrypt_key, nil) do
      nil ->
        key = :crypto.mac(:hmac, :sha256, Secret.secret_key_base(), Proxy.signing_salt() <> "-encryption")
        jwk = JOSE.JWK.from_oct(key)
        :persistent_term.put(:mu_identifier_jwt_encrypt_key, jwk)
        jwk
      jwk -> jwk
    end
  end
end
