# Author: Cody Herriges
# Pulls a selection of packages from a full Centos mirror and
# drops the packages into a requested location on the local machine
# if any packages are updated it then runs createrepo to generate
# a local yum repo.  The local repos are meant to allow PuppetMaster
# trainings to be ran in the event that internet connectivity is an
# issue.
#
# All package patterns in each local repo need to currently be with in the
# same resource.  This is due to the method of retrieving and cleaning
# up packages; each resource declaration is going to issues a `rsync
# --delete` with means that you will only get packages from the final
# resource that runs.  Suboptimal, yes and I think I am going to solve
# this with a ruby manifest at some point.
#
# If you use a `syncer` of `wget`, just provide a list of URLs to download
# each RPM file you care about. This will build a yumrepo for you with each
# of those RPMs cached appropriately.
#
# Example:
#   pkgsync { "base_pkgs":
#     pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\n",
#     repopath => "/var/yum/mirror/centos/6/os/$::architecture",
#     source   => "::centos/6/os/$::architecture/CentOS/",
#     notify   => Repobuild["base"]
#   }
#
#   repobuild { "base":
#     repopath => "${base}/mirror/centos/6/os/$::architecture",
#   }

class localrepo (
  $build_name = undef,
){

  $base = "/var/yum"

  $directories = [ "${base}",
                   "${base}/mirror",
                   "${base}/mirror/epel",
                   "${base}/mirror/epel/${::operatingsystemmajrelease}",
                   "${base}/mirror/epel/${::operatingsystemmajrelease}/local",
                   "${base}/mirror/centos",
                   "${base}/mirror/centos/${::operatingsystemmajrelease}",
                   "${base}/mirror/centos/${::operatingsystemmajrelease}/os",
                   "${base}/mirror/centos/${::operatingsystemmajrelease}/updates",
                   "${base}/mirror/centos/${::operatingsystemmajrelease}/extras",
                   "${base}/mirror/classroom",
                   "${base}/mirror/classroom/${::operatingsystemmajrelease}",
                   "${base}/mirror/classroom/${::operatingsystemmajrelease}/local", ]

  File { mode => '644', owner => root, group => root }

  include localrepo::packages

  file { $directories:
    ensure => directory,
    recurse => true,
  }

  ## Build the "base" repo
  localrepo::pkgsync { "base_pkgs":
    pkglist  => template("localrepo/base_pkgs.erb"),
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/os/$::architecture",
    syncer   => "yumdownloader",
    source   => "base",
    notify   => Localrepo::Repobuild["base_local"],
  }

  localrepo::repobuild { "base_local":
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/os/$::architecture",
    require  => Class['localrepo::packages'],
    notify   => Exec["makecache"],
  }

  ## Build the "extras" repo
  localrepo::pkgsync { "extras_pkgs":
    pkglist  => template("localrepo/extras_pkgs.erb"),
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/extras/$::architecture",
    syncer   => "yumdownloader",
    source   => "base",
    notify   => Localrepo::Repobuild["extras_local"],
  }

  localrepo::repobuild { "extras_local":
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/extras/$::architecture",
    require  => Class['localrepo::packages'],
    notify   => Exec["makecache"],
  }

  ## Build the "updates" repo
  localrepo::pkgsync { "updates_pkgs":
    pkglist  => template("localrepo/updates_pkgs.erb"),
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/updates/$::architecture",
    syncer   => "yumdownloader",
    source   => "base",
    notify   => Localrepo::Repobuild["updates_local"],
  }

  localrepo::repobuild { "updates_local":
    repopath => "${base}/mirror/centos/${::operatingsystemmajrelease}/updates/$::architecture",
    require  => Class['localrepo::packages'],
    notify   => Exec["makecache"],
  }

  ## Build the "epel" repo
  localrepo::pkgsync { "epel_pkgs":
    pkglist  => template("localrepo/epel_pkgs.erb"),
    repopath => "${base}/mirror/epel/${::operatingsystemmajrelease}/local/$::architecture",
    syncer   => "yumdownloader",
    source   => "epel",
    notify   => Localrepo::Repobuild["epel_local"],
    require  => Class['epel']
  }

  localrepo::repobuild { "epel_local":
    repopath => "${base}/mirror/epel/${::operatingsystemmajrelease}/local/$::architecture",
    require  => Class['localrepo::packages'],
    notify   => Exec["makecache"],
  }

  ## Build the "classroom" repo of misc RPMs
  localrepo::pkgsync { "classroom_pkgs":
    pkglist  => template("localrepo/classroom_pkgs.erb"),
    repopath => "${base}/mirror/classroom/${::operatingsystemmajrelease}/local/$::architecture",
    syncer   => "wget",
    notify   => Localrepo::Repobuild["classroom"],
  }

  localrepo::repobuild { "classroom":
    repopath => "${base}/mirror/classroom/${::operatingsystemmajrelease}/local/$::architecture",
    require  => Class['localrepo::packages'],
    notify   => Exec["makecache"],
  }

  exec { "makecache":
    command     => "yum makecache",
    path        => "/usr/bin",
    refreshonly => true,
    user        => root,
    group       => root,
  }
}
