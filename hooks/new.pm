# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
# # vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::New::Concourse;

use v5.20;
use warnings; # Genesis supports min perl v5.20.

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::New);

use Genesis;
use Genesis::UI qw(prompt_for_boolean);

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{features} = [];
  $obj->check_minimum_genesis_version('2.7.6');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $dir = $ENV{GENESIS_ROOT};
  my $name = $ENV{GENESIS_ENVIRONMENT};
  my $ymlfile = "$dir/$name.yml";
  my @features = ();
  my $params = "";

  info("".
       "\n#G{Concourse CI/CD Genesis Kit}".
       "\n#G{---------------------------}".
       "\n".
       "\nCreating environment #C{$name} in #C{$dir}");

  # Get kit type
  my $kit_type;
  prompt_for('kit_type', 'select',
    "Is this a full Concourse deployment, or a worker deployment for an existing Concourse?",
    '-o "[full]     Full Concourse"',
    '-o "[small-footprint]     Small Footprint Concourse"',
    '-o "[workers]  Satellite Concourse"',
    \$kit_type);

  push @features, $kit_type;

  if ($kit_type eq "full" || $kit_type eq "small-footprint") {
    $self->_configure_full_concourse(\@features, \$params);
  } elsif ($kit_type eq "workers") {
    $self->_configure_worker_concourse(\@features, \$params);
  }

  # Create the environment file
  $self->_write_environment_file($ymlfile, \@features, $params);

  # Offer environment editor
  run({ interactive => 1 }, 'offer_environment_editor');

  return $self->done(1);
}

sub _configure_full_concourse {
  my ($self, $features_ref, $params_ref) = @_;
  
  # Configure authentication
  my $auth_backend_feature;
  prompt_for('auth_backend_feature', 'select',
    "What authentication backend do you wish to use with Concourse?",
    '-o "[github-oauth]            GitHub OAuth Integration"',
    '-o "[github-enterprise-oauth] GitHub Enterprise OAuth Integration"',
    '-o "[cf-oauth]                UAA OAuth Integration"',
    '-o "[]                        HTTP Basic Auth"',
    \$auth_backend_feature);
    
  if ($auth_backend_feature) {
    push @$features_ref, $auth_backend_feature;
  }

  if ($auth_backend_feature) {
    $self->_configure_oauth($auth_backend_feature, $params_ref);
  }

  # Configure Vault integration
  $self->_configure_vault($features_ref, $params_ref);

  # Configure external database
  $self->_configure_external_db($features_ref, $params_ref);

  # Configure TLS
  $self->_configure_tls($features_ref);

  # Configure external domain
  $self->_configure_external_domain($params_ref);
}

sub _configure_worker_concourse {
  my ($self, $features_ref, $params_ref) = @_;
  
  info("".
       "\nA worker-only Concourse deployment requires an existing full host Concourse".
       "\ndeployment for the workers to connect to.");
       
  my $tsa_host_env;
  prompt_for('tsa_host_env', 'line',
    "Please specify environment name of the Concourse host deployment",
    \$tsa_host_env);

  $$params_ref .= "  tsa_host_env: $tsa_host_env\n";

  # Check if the host environment exists in vault
  my $exodus_path = $self->env->exodus_mount . $tsa_host_env . "/concourse";
  my $exists = $self->vault->exists($exodus_path);
  
  if (!$exists) {
    $self->env->notify(
      error => "No deployment details found for $tsa_host_env Concourse deployment.".
               "\nPlease ensure that it has been deployed first using Genesis v2.6 or greater and this".
               "\nversion of the Concourse Genesis Kit"
    );
    return 0;
  }
}

sub _configure_oauth {
  my ($self, $auth_backend_feature, $params_ref) = @_;
  my $vault_prefix = $ENV{GENESIS_SECRETS_BASE};
  
  if ($auth_backend_feature eq "github-oauth" || $auth_backend_feature eq "github-enterprise-oauth") {
    info("".
         "\nThe GitHub OAuth Client ID and Client Secret are needed to authenticate Concourse".
         "\nto GitHub, so that Concourse can then authorize users after they log into GitHub.".
         "\nSee https://developer.github.com/v3/oauth/ for more info.");

    my ($client_id, $client_secret);
    prompt_for('client_id', 'line', "GitHub OAuth Client ID", '-i', \$client_id);
    prompt_for('client_secret', 'line', "GitHub OAuth Client Secret", '-i', \$client_secret);
    
    $self->vault->set("${vault_prefix}oauth", "provider_key", $client_id);
    $self->vault->set("${vault_prefix}oauth", "provider_secret", $client_secret);

    info("".
         "\nConcourse authorizes access based off of GitHub Organizations");
         
    my $authz_allowed_orgs;
    prompt_for('authz_allowed_orgs', 'line',
      "Which GitHub organization do you want to grant access to Concourse?",
      \$authz_allowed_orgs);
      
    $$params_ref .= "  authz_allowed_orgs: $authz_allowed_orgs\n";

    if ($auth_backend_feature eq "github-enterprise-oauth") {
      info("".
           "\nWhat is the GitHub Enterprise hostname? example: github.example.com");
           
      my $github_host;
      prompt_for('github_host', 'line', "GitHub Enterprise Hostname:", '-i', \$github_host);
      
      $$params_ref .= "  github_host: $github_host\n";
    }
  } elsif ($auth_backend_feature eq "cf-oauth") {
    info("".
         "\nThe UAA client id and secret is needed to authenticate Concourse to the UAA,".
         "\nso that Concourse can then authorize users after they log into the UAA.");
         
    my ($client_id, $client_secret);
    prompt_for('client_id', 'line', "UAA Client ID:", '-i', \$client_id);
    prompt_for('client_secret', 'line', "UAA Client Secret:", '-i', \$client_secret);
    
    $self->vault->set("${vault_prefix}oauth", "provider_key", $client_id);
    $self->vault->set("${vault_prefix}oauth", "provider_secret", $client_secret);

    info("".
         "\nWhat is the URL of the CF installation that will be used for UAA-based".
         "\nauthentication. Should be the same URL that is used to log in to the CF".
         "\ninstallation.");
         
    my $cf_base_url;
    prompt_for('cf_base_url', 'line',
      "Cloud Foundry Base URL:", '-i', '-V', 'url',
      \$cf_base_url);
      
    my $cf_scheme = $cf_base_url;
    if ($cf_base_url =~ /^(https?):\/\/(.*)/) {
      $cf_scheme = $1;
      $cf_base_url = $2;
    } else {
      $cf_scheme = "https";
    }
    
    my $cf_api_url;
    prompt_for('cf_api_url', 'line',
      "Cloud Foundry API URL:", '-i',
      "--default", "${cf_scheme}://api.system.${cf_base_url}",
      '-V', 'url',
      \$cf_api_url);
      
    $$params_ref .= "  cf_api_url: $cf_api_url\n";

    info("".
         "\nThe Cloud Foundry CA cert is used to authenticate Concourse to the UAA,".
         "\nso that Concourse can then authorize users after they log into the UAA.".
         "\nThis is usually something like '#C{secret/path/to/keys/for/haproxy/ssl:certificate}'".
         "\nIf you are unsure, use '#G{safe tree}' to find it. If you are terminating ssl on LBs or".
         "\nGo routers, you will need cert on those nodes.");
         
    my $cf_ca_cert_vault_path;
    prompt_for('cf_ca_cert_vault_path', 'line',
      "What is your CF CA cert path?",
      '-V', 'vault_path_and_key',
      \$cf_ca_cert_vault_path);
      
    $$params_ref .= "  cf_ca_cert_vault_path: $cf_ca_cert_vault_path\n";

    my @cf_spaces;
    prompt_for('cf_spaces', 'multi-line',
      "What CF spaces do you want to grant access to Concourse?",
      \@cf_spaces);
      
    if (@cf_spaces) {
      $$params_ref .= "  cf_spaces:\n";
      for my $space (@cf_spaces) {
        $$params_ref .= "    - $space\n";
      }
    }
  }
}

sub _configure_vault {
  my ($self, $features_ref, $params_ref) = @_;
  
  my $use_vault;
  prompt_for('use_vault', 'select',
    "Vault integration for secret storage:",
    '-o "[vault]         Use static token"',
    '-o "[vault-approle] Use approle (generate via genesis <env> do setup-approle)"',
    '-o "[]              No secret storage integration"',
    \$use_vault);

  if ($use_vault) {
    if ($use_vault eq "vault-approle") {
      push @$features_ref, "vault";
    }
    push @$features_ref, $use_vault;

    my $vault_url;
    prompt_for('vault_url', 'line', '-i',
      "Vault URL:",
      "--default", "$ENV{GENESIS_TARGET_VAULT}",
      '-V', 'url',
      \$vault_url);
      
    $$params_ref .= "  vault_url: $vault_url\n";

    my $vault_insecure_skip_verify;
    prompt_for('vault_insecure_skip_verify', 'boolean', 
      "Allow insecure connection?", "--default", "yes", "--inline",
      \$vault_insecure_skip_verify);
      
    if ($vault_insecure_skip_verify) {
      $$params_ref .= "  vault_insecure_skip_verify: true\n";
    }

    my $vault_path_prefix;
    prompt_for('vault_path_prefix', 'line', '-i',
      "Vault Path Prefix:",
      "--default", '/concourse',
      \$vault_path_prefix);
      
    if ($vault_path_prefix ne '/concourse') {
      $$params_ref .= "  vault_path_prefix: $vault_path_prefix\n";
    }

    if ($use_vault eq "vault") {
      my $token;
      prompt_for('vault:token', 'secret-line', "Vault Token", \$token);
    } elsif ($use_vault eq "vault-approle") {
      info(''.
           "\nYou must run #C{$ENV{GENESIS_CALL_ENV} do -- setup-approle} before deploying to build the".
           "\nconcourse approle.");
    }
  }
}

sub _configure_external_db {
  my ($self, $features_ref, $params_ref) = @_;
  
  my $use_external_db;
  prompt_for('use_external_db', 'boolean', 
    "Do you want to use an external database?", "--default", "no", "--inline",
    \$use_external_db);
    
  if ($use_external_db) {
    push @$features_ref, "external-db";
    
    my $external_db_host;
    prompt_for('external_db_host', 'line', 
      "Enter the host of the database using IP or FQDN.",
      \$external_db_host);
      
    $$params_ref .= "  external_db_host: $external_db_host\n";
    
    my $external_db_port;
    prompt_for('external_db_port', 'line', 
      "The port that the database is listening on.",
      "--default", "5432",
      "--validation", "port",
      \$external_db_port);
      
    if ($external_db_port ne "5432") {
      $$params_ref .= "  external_db_port: $external_db_port\n";
    }
    
    my $external_db_name;
    prompt_for('external_db_name', 'line', 
      "The name of the database to connect to.", "--default", "atc",
      \$external_db_name);
      
    if ($external_db_name ne "atc") {
      $$params_ref .= "  external_db_name: $external_db_name\n";
    }
    
    my $external_db_user;
    prompt_for('external_db_user', 'line', 
      "The username used to connect to the database.", "--default", "atc",
      \$external_db_user);
      
    if ($external_db_user ne "atc") {
      $$params_ref .= "  external_db_user: $external_db_user\n";
    }
    
    my $password;
    prompt_for('database/external:password', 'secret-line',
      "The password for the '$external_db_user' database user.",
      \$password);
    
    my $external_db_sslmode;
    prompt_for('external_db_sslmode', "select",
      "The sslmode parameter to connect to the database with.",
      "--default", "verify-ca",
      "--option", "[disable] disable - No security, and no overhead for encryption.",
      "--option", "[allow] allow - Only use SSL if the server insists on it.",
      "--option", "[prefer] prefer - Use SSL if the server supports it.",
      "--option", "[require] require - Use SSL but do not verify the certificate.",
      "--option", "[verify-ca] verfiy-ca - Use SSL and verify the CA certificate.",
      "--option", "[verify-full] verify-full - Use SLL and verify the certificate chain.",
      \$external_db_sslmode);
      
    if ($external_db_sslmode ne "verify-ca") {
      $$params_ref .= "  external_db_sslmode: $external_db_sslmode\n";
    }
    
    if ($external_db_sslmode =~ /^verify-/) {
      my $use_external_db_ca;
      prompt_for('use_external_db_ca', 'boolean', 
        "Do you want to provide your own ca certificate for $external_db_sslmode mode?", 
        "--default", "no", "--inline",
        \$use_external_db_ca);
        
      if ($use_external_db_ca) {
        push @$features_ref, "external-db-ca";
        
        my $external_db_ca;
        prompt_for('external_db_ca', 'block', 
          "The sslmode ca certificate required for sslmode $external_db_sslmode.",
          \$external_db_ca);
          
        $$params_ref .= "  external_db_ca: |\n";
        for my $line (split /\n/, $external_db_ca) {
          $$params_ref .= "    $line\n";
        }
      }
    }
  }
}

sub _configure_tls {
  my ($self, $features_ref) = @_;
  
  info("".
       "\nConcourse should be protected by TLS, since build logs may contain".
       "\nsensitive information (like IPs, usernames, etc.).");
       
  my $ssl_cert_feature;
  prompt_for('ssl_cert_feature', 'select',
    "How would you like to configure Concourse TLS?",
    '-o "[provided-cert]    I have my own certificate for Concourse"',
    '-o "[self-signed-cert] Please have Genesis create a self-signed certificate for Concourse"',
    '-o "[no-tls]           Do not; an upstream proxy / load balancer is handling TLS"',
    \$ssl_cert_feature);
    
  push @$features_ref, $ssl_cert_feature;

  if ($ssl_cert_feature eq "provided-cert") {
    my $certificate;
    prompt_for('ssl/server:certificate', 'secret-block',
      "What is the SSL certificate for Concourse?",
      \$certificate);

    my $key;
    prompt_for('ssl/server:key', 'secret-block',
      "What is the SSL key for Concourse?",
      \$key);
  }
}

sub _configure_external_domain {
  my ($self, $params_ref) = @_;
  
  info("".
       "\nThe external domain for concourse is the DNS entry users will use to access".
       "\nConcourse. You can specify the IP address if you don't have a DNS entry. Do".
       "\nnot include 'https://' in this value.");
       
  my $external_domain;
  prompt_for('external_domain', 'line', "External Domain or IP:", '-i',
    \$external_domain);
    
  $$params_ref .= "  external_domain: $external_domain\n";

  info("".
       "\nThe main target is the name that will be used by fly to connect to the main".
       "\nteam. This defaults to the name of the environment, but can be given a short-".
       "\nhand name for convenience. Team-based targets will be the name of the team,".
       "\nfollowed by @<main-target->");
       
  my $main_target;
  prompt_for('main_target', 'line', "Master target name", '-i', "--default", "$ENV{GENESIS_ENVIRONMENT}",
    \$main_target);
    
  if ($main_target ne $ENV{GENESIS_ENVIRONMENT}) {
    $$params_ref .= "  main_target: $main_target\n";
  }
}

sub _write_environment_file {
  my ($self, $filename, $features_ref, $params) = @_;
  
  open(my $fh, '>', $filename) or bail("Could not open $filename for writing: $!");
  
  # Write the header
  print $fh "---\n";
  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features:\n";
  print $fh "    - (( replace ))\n";
  
  # Write the features
  for my $feature (@$features_ref) {
    print $fh "    - $feature\n";
  }
  
  # Write the genesis config block
  my ($out, $rc) = run('genesis_config_block');
  print $fh $out;
  
  # Write the params
  if ($params) {
    print $fh "\nparams:\n$params";
  }
  
  close $fh;
  
  info("".
       "\nWrote configuration to #C{$filename}.");
}

1;

