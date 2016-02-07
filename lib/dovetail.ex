defmodule Dovetail do
  @moduledoc """
  The `Dovetail` module provides the public API.

  ## Install

  `Dovetail.config/0` must be run before first starting dovecot. Note that the
  return is suppressed here because I don't want to explicitly match dovetails
  return values.

      iex> Dovetail.config(); :ok
      :ok

  ## Examples

      iex> Dovetail.up?
      false
      iex> Dovetail.start()
      :ok
      iex> Dovetail.up?
      true
      iex> Dovetail.stop()
      :ok
      iex> Dovetail.up?
      false

  """

  alias Dovetail.Process
  alias Dovetail.UserStore
  alias Dovetail.Config

  # TODO - this should be defined elsewhere
  @dovecot Application.app_dir(:dovetail, "priv/dovecot/sbin/dovecot")
  @pass_db Application.app_dir(:dovetail, "pass.db")

  @doc """
  Check if dovecot is up.
  """
  def up?(options \\ []) do
    case Process.pgrep(["-f", Keyword.get(options, :path, @dovecot)]) do
      {:ok, _}    -> true
      {:error, _} -> false
    end
  end

  @doc """
  Start the dovecot server with the default settings.

  See `dovecot/0`.

  ## Options

   * `:config :: String.t` the path to the config file
  """
  def start(options \\ []) do
    case Process.dovecot(["-c", Dict.get(options, :config,
                                         Config.target_path())]) do
      {:ok, ""}               -> :ok
      {:error, {:status, 89}} -> {:error, :already_started}
      {:error, reason}        -> {:error, reason}
    end
  end

  @doc """
  Start the dovecot server with the default settings.

  See `doveadm(["stop"])`.
  """
  def stop do
    case Process.doveadm(["stop"]) do
      {:ok, ""}               -> :ok
      {:error, {:status, 75}} -> {:error, :already_stopped}
      {:error, reason}        -> {:error, reason}
    end
  end

  @doc """
  Reload the configure by calling `doveadm reload`.
  """
  @spec reload :: :ok | {:error, any}
  def reload do
    case Process.doveadm(["reload"]) do
      {:ok, ""}         -> :ok
      {:error, _} = err -> err
    end
  end

  @doc """
  Create the dovecot server's configuration, reloading it if dovecot is
  running.
  """
  @spec config(Keyword.t) :: {:ok, Keyword.t} | {:error, any}
  def config(opts \\ []) do
    conf_path = Dict.get(opts, :target, Config.target_path())
    template_opts = opts
    |> Dict.take([:default_user, :log_path, :passdb_path])
    |> Config.template()
    |> Config.write!(conf_path)
    if up? do
      case reload() do
        :ok -> {:ok, template_opts}
        any -> any
      end
    else
      {:ok, template_opts}
    end
  end

  @doc """
  Get the user store.

  See `Dovetail.UserStore`.
  """
  @spec get_user_store :: {:ok, UserStore.t} | {:error, any}
  def get_user_store do
    {:ok, UserStore.PasswordFile.new!(@pass_db)}
  end

end