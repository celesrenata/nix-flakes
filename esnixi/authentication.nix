{
  config = {
    # Authentication.
    users.extraUsers = rec {
 we      admin = { name = "celes"; group = "users"; };
      ollama = { name = "ollama"; group = "users"; };
    };

    # Set default user permissions.
    users.groups.users.userInsertionLimit = 20;

    # Enable SSH access for authenticated users.
    services.ssh.enable = true;
  };
}
