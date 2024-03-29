#' Create a new droplet.
#'
#' There are defaults for each of size, image, and region so that a quick
#' one-liner with one parameter is possible: simply specify the name of the
#' droplet and your'e up and running.
#'
#' @export
#' @param name (character) Name of the droplet. The human-readable string you
#'   wish to use when displaying the Droplet name. The name, if set to a domain
#'   name managed in the DigitalOcean DNS management system, will configure a
#'   PTR record for the Droplet. The name set during creation will also
#'   determine the hostname for the Droplet in its internal configuration.
#'   Default: picks a random name from \code{\link{words}} if none supplied.
#' @param size (character) Size slug identifier. See \code{\link{sizes}()} for
#'   a complete list. Default: s-1vcpu-1gb, the smallest
#' @param image (character/numeric) The image ID of a public or private image,
#'   or the unique slug identifier for a public image. This image will be the
#'   base image for your droplet. See \code{\link{images}()} for a complete
#'   list. Use rstudio-20-04 for a DigitalOcean Marketplace image with R and
#'   Tidyverse readily available. Default: ubuntu-18-04-x64
#' @param region (character) The unique slug identifier for the region that you
#'   wish to deploy in. See \code{\link{regions}()} for a complete list.
#'   Default: sfo3
#' @param ssh_keys (character) A character vector of key names, an integer
#'   vector of key ids, or NULL, to use all keys in your account. Accounts
#'   with the corresponding private key will be able to log in to the droplet.
#'   See \code{\link{keys}()} for a list of the keys that you've added.
#'   Default: NULL
#' @param private_networking (logical) Use private networking. Private
#'   networking is currently only available in certain regions.
#'   Default: \code{FALSE}
#' @param tags (character) A vector of tag names to apply to the Droplet after
#'   it is created. Tag names can either be existing or new tags.
#'   Default: list()
#' @param backups (logical) Enable backups. A boolean indicating whether
#'   automated backups should be enabled for the droplet. Automated backups can
#'   only be enabled when the droplet is created, and cost extra.
#'   Default: FALSE
#' @param ipv6 (logical) A boolean indicating whether IPv6 is enabled on the
#'   droplet.
#' @param user_data (character) Gets passed to the droplet at boot time. Not
#'   all regions have this enabled, and is not used by all images.
#' @param cloud_config (character) Specify the name of a cloud config template
#'   to automatically generate \code{\link{cloud_config}} and submit in
#'   user metadata. Setting this is best practice: the built-in templates
#'   use security best practices (disabling root log-in, security autoupdates)
#'   to make it harder to hack your droplet.
#' @param wait If \code{TRUE} (default), wait until droplet has been
#' initialised and is ready for use. If set to \code{FALSE} we return a
#' droplet object right away after droplet creation request has been sent.
#' Note that there won't be an IP address in the object yet. Note that
#' waiting means we ping the DigitalOcean API to check on the status of your
#' droplet, which uses up your API requests. The option \code{do.wait_time}
#' can be set to any positive integer to determine how many seconds between
#' pings. The default is 1 sec. Note that if you are creating droplets in a
#' loop, parallel or otherwise, set \code{do.wait_time} within the loop
#' instead of outside of it.
#'
#' @param ... Additional options passed down to \code{\link[httr]{POST}}
#'
#' @details Note that if you exit the R session or kill the function call
#' after it's in waiting process (the string of ...), the droplet creation
#' will continue.
#' @template dropid
#'
#' @return A droplet object
#'
#' @examples \dontrun{
#' # by default we give your droplet a name
#' droplet_create()
#'
#' # you can set your own droplet name
#' droplet_create('droppinit')
#'
#' # set name, size, image, and region
#' droplet_create(name="newdrop", size = '512mb', image = 'ubuntu-14-04-x64',
#'   region = 'sfo3')
#'
#' # use an ssh key
#' droplet_create(ssh_keys=89103)
#'
#' # add tags
#' (d <- droplet_create(tags = c('venus', 'mars')))
#' summary(d)
#' }
droplet_create <- function(name = random_name(),
                        size = getOption("do_size", "s-1vcpu-1gb"),
                        image = getOption("do_image", "ubuntu-18-04-x64"),
                        region = getOption("do_region", "sfo3"),
                        ssh_keys = getOption("do_ssh_keys", NULL),
                        backups = getOption("do_backups", NULL),
                        ipv6 = getOption("do_ipv6", NULL),
                        private_networking =
                          getOption("do_private_networking", NULL),
                        tags = list(),
                        user_data = NULL,
                        cloud_config = NULL,
                        wait = TRUE,
                        ...) {

  ssh_keys <- standardise_keys(ssh_keys)
  if (length(ssh_keys) == 0) {
    warning("You have not specified any ssh_keys. This is NOT recommended.",
      " (You will receive an email with the root password in a few minutes)",
      call. = FALSE)
  }

  # Generate user_data if cloud_config specified
  if (!is.null(cloud_config)) {
    if (!is.null(user_data)) {
      stop("You may only specify one of cloud_config and user_data.",
        call. = FALSE)
    }

    user_data <- cloud_config(cloud_config, ssh_keys)
  }

  res <- do_POST('droplets',
                 body = list(
                   name = unbox(name),
                   size = unbox(size),
                   image = unbox(image),
                   region = unbox(region),
                   ssh_keys = I(ssh_keys),
                   backups = unbox(backups),
                   ipv6 = unbox(ipv6),
                   private_networking = unbox(private_networking),
                   tags = I(tags),
                   user_data = unbox(user_data)
                 ), ...
  )
  dres <- droplet(res$droplet$id)
  message("NB: This costs $", dres$size$price_hourly, " / hour ",
          "until you droplet_delete() it")

  if (wait) {
    droplet_wait(dres)
    droplet(dres$id)
  } else {
    droplet(dres$id)
  }
}

# random_name <- function() sample(words, size = 1)
random_name <- function(){
  sample_upcase <- function(x) capwords(sample(x, size = 1))
  paste0(sample_upcase(adjectives), sample_upcase(nouns))
}

capwords <- function(s, strict = FALSE, onlyfirst = FALSE) {
  cap <- function(s) paste(toupper(substring(s, 1, 1)), {
    s <- substring(s,2); if (strict) tolower(s) else s}, sep = "",
    collapse = " " )
  if (!onlyfirst) {
    sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s)))
  } else {
    sapply(s, function(x)
      paste(toupper(substring(x,1,1)),
            tolower(substring(x,2)),
            sep = "", collapse = " "), USE.NAMES = FALSE)
  }
}

#' Wait for a droplet to be ready.
#'
#' @param droplet  A droplet, or something that can be coerced to a droplet by
#'   \code{\link{as.droplet}}.
#' @export
#' @examples
#' \dontrun{
#' droplet_create() %>% droplet_wait()
#' }
droplet_wait <- function(droplet) {
  droplet <- as.droplet(droplet)

  action <- droplet_actions(droplet)[[1]]
  action_wait(action)
}


#' Delete a droplet.
#'
#' This method deletes one of your droplets - this is irreversible.
#'
#' @export
#' @param droplet A droplet, or something that can be coerced to a droplet by
#'   \code{\link{as.droplet}}.
#' @param tag (character) Name of a tag. optional
#' @param ... Additional options passed down to low-level API method.
#' @examples
#' \dontrun{
#' drops <- droplets()
#' drops[[1]] %>% droplet_delete()
#' drops[[2]] %>% droplet_delete()
#' droplet_create() %>% droplet_delete()
#'
#' droplet_delete("lombard")
#' droplet_delete(12345)
#'
#' # Delete all droplets
#' lapply(droplets(), droplet_delete)
#'
#' # delete droplets by tag
#' ## first, create a tag, then a droplet, then tag it
#' tag_create(name = "foobar")
#' e <- droplet_create()
#' tag_resource(name = "foobar", resource_id = e$id)
#' droplets(tag = "foobar")
#' ## then delete the droplet by tag name
#' droplet_delete(tag = "foobar")
#' }
droplet_delete <- function(droplet = NULL, tag = NULL, ...) {
  if (!is.null(droplet)) {
    droplet <- as.droplet(droplet)
    do_DELETE(sprintf('droplets/%s', droplet$id), ...)
  } else {
    do_DELETE('droplets', query = ascompact(list(tag_name = tag)), ...)
  }
}


#' Perform various actions on a droplet.
#'
#' These droplet actions have no further arguments.
#'
#' \describe{
#' \item{reboot}{This method allows you to reboot a droplet. This is
#'   the preferred method to use if a server is not responding}
#' \item{powercycle}{This method allows you to power cycle a droplet.
#'    This will turn off the droplet and then turn it back on.}
#' \item{shutdown}{Shutdown a running droplet. The droplet will remain in
#'   your account and you will continue to be charged for it.}
#' \item{power_off}{Shutdown a running droplet. The droplet will remain in
#'   your account and you will continue to be charged for it.}
#' \item{reset_password}{This method will reset the root password for a
#'   droplet. Please be aware that this will reboot the droplet to allow
#'   resetting the password.}
#' \item{enable_ipv6}{Enable IPv6 networking on an existing droplet (within
#'   a region that has IPv6 available).}
#' \item{enable_private_networking}{Enable private networking on an existing
#'   droplet (within a region that has private networking available)}
#' \item{disable_backups}{Disables backups for a droplet.}
#' \item{enable_backups}{Enables backups for a droplet.}
#' \item{power_on}{Turn on a droplet that's turned off.}
#' }
#' @inheritParams droplet_delete
#' @examples \dontrun{
#' d <- droplets()
#' d[[1]] %>% droplet_reboot()
#' d[[2]] %>% droplet_power_cycle()
#'
#' d <- droplet_create()
#' d %>% summary
#' d %>% droplet_enable_backups()
#' d %>% summary
#' }
#' @name droplet_action
NULL

#' @export
#' @rdname droplet_action
droplet_reboot <- function(droplet, ...) {
  droplet_action("reboot", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_power_cycle <- function(droplet, ...) {
  droplet_action("power_cycle", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_shutdown <- function(droplet, ...) {
  droplet_action("shutdown", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_power_off <- function(droplet, ...) {
  droplet_action("power_off", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_power_on <- function(droplet, ...) {
  droplet_action("power_on", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_reset_password <- function(droplet, ...) {
  droplet_action("reset_password", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_enable_ipv6 <- function(droplet, ...) {
  droplet_action("enable_ipv6", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_enable_private_networking <- function(droplet, ...) {
  droplet_action("enable_private_networking", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_enable_backups <- function(droplet, ...) {
  droplet_action("enable_backups", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_disable_backups <- function(droplet, ...) {
  droplet_action("disable_backups", droplet, ...)
}

#' @export
#' @rdname droplet_action
droplet_upgrade <- function(droplet, ...) {
  droplet_action("migrate_droplet", droplet, ...)
}

droplet_action <- function(action, droplet, ...) {
  droplet <- as.droplet(droplet)

  res <- do_POST(sprintf('droplets/%s/actions', droplet$id),
    httr::content_type_json(),
    body = list(type = jsonlite::unbox(action), ...))
  as.action(res)
}


#' Modify a droplet.
#'
#' These methods allow you to modify existing droplets.
#'
#' \describe{
#' \item{resize}{Resize a specific droplet to a different size. This will
#'   affect the number of processors and memory allocated to the droplet.}
#' \item{rebuild}{Reinstall a droplet with a default image. This is useful
#'   if you want to start again but retain the same IP address for your
#'   droplet.}
#' \item{rename}{Change the droplet name}
#' \item{change_kernel}{Change kernel ID.}
#' }
#'
#' @inheritParams droplet_delete
#' @param size (character) Size slug (name) of the image size. See \code{sizes}
#' @details Beware: \code{droplet_resize()} does not seem to work, see
#' \code{resize()}
#' @examples \dontrun{
#' droplets()[[1]] %>% droplet_rename(name='newname')
#' }
#' @name droplet_modify
NULL

#' @export
#' @rdname droplet_modify
droplet_resize <- function(droplet, size, ...) {
  droplet_action("resize", droplet, size = jsonlite::unbox(size), ...)
}

#' @export
#' @rdname droplet_modify
#' @param image (optional) The image ID of the backup image that you would
#' like to restore.
droplet_rebuild <- function(droplet, image, ...) {
  droplet_action("rebuild", droplet, image = jsonlite::unbox(image), ...)
}

#' @export
#' @rdname droplet_modify
#' @param name (character) The new name for the droplet
droplet_rename <- function(droplet, name, ...) {
  droplet_action("rename", droplet, name = jsonlite::unbox(name), ...)
}

#' @export
#' @rdname droplet_modify
#' @param kernel (numeric) The ID of the new kernel.
droplet_change_kernel <- function(droplet, kernel, ...) {
  droplet_action("change_kernel", droplet, kernel = jsonlite::unbox(kernel),
    ...)
}

#' Take and restore snapshots.
#'
#' \describe{
#' \item{snapshot}{Take a snapshot of the droplet once it has been powered
#'   off, which can later be restored or used to create a new droplet from
#'   the same image.}
#' \item{snapshots_list}{List available snapshots}
#' \item{backups_list}{List available snapshots}
#' \item{restore}{Restore a droplet with a previous image or snapshot.
#'   This will be a mirror copy of the image or snapshot to your droplet. Be
#'   sure you have backed up any necessary information prior to restore.}
#' }
#'
#' @param droplet A droplet number or the result from a call to
#' \code{droplets()}
#' @param name (character) Optional. Name of the new snapshot you want to
#' create. If not set, the  snapshot name will default to the current date/time
#' @param image (optional) The image ID of the backup image that you would like
#' to restore.
#' @param wait If \code{TRUE} (default), wait until the snapshot has been
#' completed and is ready for use. If set to \code{FALSE} we return a
#' droplet object right away after droplet snapshot request has been sent.
#' @param ... Additional options passed down to \code{\link[httr]{POST}}
#' @examples \dontrun{
#' d <- droplet_create()
#' d %>% droplet_snapshots_list()
#' d %>% droplet_backups_list()
#'
#' d %>%
#'   droplet_snapshot() %>%
#'   droplet_power_on() %>%
#'   droplet_snapshots_list()
#'
#' # To delete safely
#' d %>%
#'   droplet_snapshot() %>%
#'   droplet_delete() %>%
#'   action_wait()
#' }
#' @export
droplet_snapshot <- function(droplet, name = NULL, wait = TRUE, ...) {
  droplet_status <- droplet$status
  droplet_power_off(droplet)
  droplet_wait(droplet)

  droplet_action("snapshot", droplet, name = name, ...)

  if (wait) {
    droplet_wait(droplet)
    droplet
  } else {
    droplet
  }
}

#' @export
#' @rdname droplet_snapshot
droplet_snapshots_list <- function(droplet, ...) {
  droplet <- as.droplet(droplet)

  res <- do_GET(sprintf('droplets/%s/snapshots', droplet$id), ...)
  list_to_object(res, "snapshot", class = "image")
}

#' @export
#' @rdname droplet_snapshot
droplet_restore <- function(droplet, image, ...) {
  droplet_action("restore", droplet, image = jsonlite::unbox(image), ...)
}

#' @export
#' @rdname droplet_snapshot
droplet_backups_list <- function(droplet, ...) {
  droplet <- as.droplet(droplet)

  res <- do_GET(sprintf('droplets/%s/backups', droplet$id), ...)
  res$backups
}


#' List all available kernels for a droplet.
#'
#' @export
#' @inheritParams droplet_delete
#' @examples \dontrun{
#' droplets()[[1]] %>% droplet_kernels_list
#' }
droplet_kernels_list <- function(droplet, ...) {
  droplet <- as.droplet(droplet)

  res <- do_GET(sprintf('droplets/%s/kernels', droplet$id), ...)
  res$kernels
}

#' List all droplets that are scheduled to be upgraded.
#'
#' @export
#' @param ... Additional options passed down to low-level API method.
#' @examples \dontrun{
#' droplet_upgrades_list()
#' }
droplet_upgrades_list <- function(...) do_GET('droplet_upgrades', ...)

#' Retrieve a droplet action or list all actions associatd with a droplet.
#'
#' @export
#' @inheritParams droplet_delete
#' @param actionid (integer) Optional. An action id.
#' @examples \dontrun{
#' droplet_actions(2428384)
#' droplet_actions(2428384, actionid=31223385)
#' }
droplet_actions <- function(droplet, actionid = NULL, ...) {
  droplet <- as.droplet(droplet)
  path <- if (is.null(actionid))
    sprintf('droplets/%s/actions', droplet$id)
  else
    sprintf('droplets/%s/actions/%s', droplet$id, actionid)
  res <- do_GET(path, ...)
  as.action(res)
}

#' List neighbors
#'
#' @export
#' @inheritParams droplet_delete
#' @examples \dontrun{
#' # List a droplet's neighbors on the same physical server
#' droplets()[[3]] %>% droplet_neighbors()
#' # List all neighbors on the same physical server
#' neighbors()
#' }
neighbors <- function(...) {
  res <- do_GET('reports/droplet_neighbors_ids', ...)
  res$neighbor_ids
}

#' @export
#' @rdname neighbors
droplet_neighbors <- function(droplet, ...) {
  droplet <- as.droplet(droplet)

  res <- do_GET(sprintf('droplets/%s/neighbors', droplet$id), ...)
  res$droplets
}

#' Get droplet's IP address
#'
#' @export
#' @inheritParams droplet_delete
#' @examples \dontrun{
#' # Obtain the droplet's IP as a string
#' my_droplet <- droplet_create("demo", region = "sfo3")
#' droplet_ip(my_droplet)
#' }
droplet_ip <- function(droplet) {
  v4 <- droplet$networks$v4
  if (length(v4) == 0) {
    stop("No network interface registered for this droplet\n  Try refreshing like: droplet(d$id)",
         call. = FALSE
    )
  }
  ips <- do.call("rbind", lapply(v4, as.data.frame))
  public_ip <- ips$type == "public"
  if (!any(public_ip)) {
    ip <- v4[[1]]$ip_address
  } else {
    ip <- ips$ip_address[public_ip][[1]]
  }
  ip
}
