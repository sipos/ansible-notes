# Ansible Notes

Manages configuration. Connects to target machines using SSH, uses python on target machines (except for `raw` and `script` modules, which can be used to bootstrap).

Uses [Inventory](#inventory) of hosts. Applies either individual modules (run using `ansible`, or [Playbooks](#playbooks)).

Assumes sudo and ssh will be passwordless. Use `--ask-pass` for SSH passwords, `--ask-become-pass` for sudo (or su etc) password, and `--private-key` to specify the key file to use for SSH (in PEM format).

## Running individual modules

Use `ansible`, e.g. `ansible all -m debug -u nick --sudo --sudo-user admin`. 

Can also run a raw command with `ansible all -a "/bin/echo hello world"` (`-a` is module arguments, default module just runs the command specified by arguments).

`-C` or `--check` just tries to predict what would be done, without doing anything.

`--list-hosts` lists matching hosts.

`-i inventory_file_path` sets inventory file.

It is possible to run time-limited background operations with the `-B` and `-P` options.

The `shell` module runs commands with a shell. `ignore_errors` will disable quitting after the first error. The `command` module runs a command without a shell.

The `copy` module copies files from `src` argument on local machine to `dest` argument on remote machines. Allows `mode` argument to set mode, `owner` and `group`.

The `file` module sets file attributes using the same arguments as `copy` (minus `src`).

The `template` module creates files from templates (`src`, `dest` are required, `mode`, `group` and `owner` also accepted). Extra variables `ansible_managed`, `template_host`, `template_uid`, `template_path`, `template_full_path` and `template_fun_date` are also usable.

The `yum`, `apt` and `portage` modules can be used to install, remove or upgrade packages. `name` (`package` for `portage`) can be the name of a package or version, e.g. `name-1.0`. `state` can be `absent`, `latest`, or `present`. For `portage` `changed_use` includes packages where `USE` has changed since installation, `deep` considers the entire depgraph, `newuse` is like `changed_use` except includes when unused flags have changed, `noreplace` does not merge already merged packages, `oneshot` does not add to the world file, `sync` does an `emerge --sync`, `update` updates packages, `verbose` added verbosity, `usepkgonly` uses only compiled packages, `getbinpkg` prefers bin packages, `onlydeps` only merges dependencies, `depclean` removes a packages and dependencies that are not needed by other packages, or all unneeded packages when run without a package. 

The `user` module can be used to create or remove users. `name` specifies the user name, `state=absent` to remove, `create_home` creates home dir, `generate_ssh_key` generates a key, `password` sets a password (mkpasswd can generate password hash), `shell` sets the shell, `comment` sets the comment/GECOS field, `system` controls whether to create a system account and `groups` sets their groups.

The `git` module can checkout from a git repo, with `repo` being the repo URI, `dest` being the destination (source goes inside the dest folder, not in a folder named after the repo inside it), and `version` being the version (e.g. `HEAD`).

The `service` module can start/stop/restart services with `name` being the service and `state` being `started`, `stopped` or `restarted`. 

The `setup` module gathers facts.

The `group_by` module can be used to make groups based on facts to use later in playbooks.

The `mail` module can be used to send mail, with the `subject`, `to` and `body` properties. e.g.

```
  tasks:
  - name: Send summary mail
    local_action:
      module: mail
      subject: "Summary Mail"
      to: "{{ mail_recipient }}"
      body: "{{ mail_body }}"
    run_once: True
```

`local_action` runs something locally. Use either single line form, e.g. `local_action: command /usr/bin/take_out_of_pool {{ inventory_hostname }}` or `module: <module_name>` for multiple attributes. 

## Inventory

Ansible uses inventory files, which uses INI format, to specify hosts to act on, groups of hosts. Variables can be specified in inventory files.

```
[localhost]
localhost ansible_connection=local ansible_python_interpreter="/usr/bin/env python"
```

Inventory can also be generated dynamically.

Default inventory file is `/etc/ansible/hosts`.

`ansible-inventory` displays the inventory (see options).

`ansible_port`, `ansible_host`, `ansible_connection`, `ansible_ssh_private_key_file` and `ansible_user` are also useful options (port can be specified with a colon after the hostname).

Ranges can be used, e.g. `db-[a:f].example.com`.

Groups variables can be defined per group in a `[group_name:vars]` section.

Groups of groups can be made with `[group_name:children]` sections.

The groups `all` and `ungrouped` (all not in a group) exist by default.

`host_vars/hostname` and `group_vars/group_name` can contain group or host variables in INI, JSON (with `.json` extension) or YAML (with `.yml` or `.yaml` extensions). Instead of files, you can use directories named after hosts or groups and files are read in lexicographical order. This can be in playbook or in the inventory dir. Playbook variables overwrite ones in inventory.

Variables from the `all` group (parent of all groups) are read first, followed by parent groups, child groups, and host specific ones, with later overwriting former.

### EC2

Using `ansible -i ec2.py` after making the `ec2.py` script executable and setting `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables. 

Running it with `--list` lists hosts.

Might want to edit `ec2.ini` to comment out unneeded regions and services for speed.

All hosts are in the `ec2` group, a group for their instance ID (e.g. `i-00112233`), a group for their region (e.g. `us-east-1`), their availability zone (e.g. `us-east-1a`), a group for the security group with all non-alphanumeric characters replaced with underscores, and by tags with `tag_NAME_VALUE` where `NAME` is the name of the tag, and `VALUE` is the value of it (e.g. `tag_name_web_master_001`) (again with non-alphanumerics replaced with underscores).

Many variables are set, including `ec2_dns_name`, `ec2_id`, `ec2_image_id`, `ec2_instance_type`, `ec2_ip_address`, `ec2_kernel`, `ec2_key_name`, `ec2_launch_time`, `ec2_region`, `ec2_security_group_ids` (comma separated list), `ec2_security_group_names` (comma separated list) and `ec2_vpc_id`.

The `--refresh-cache` option clears the cached results.

The environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` need to be set to appropriate values (unless you pass them as module arguments to each module). 

### Dynamic inventory

The inventory can be added to, or created, at runtime. The `add_host` module adds to the inventory.

```
- hosts: localhost
  connection: local
  gather_facts: False

  tasks:

    - name: Provision a set of instances
      ec2:
         key_name: my_key
         group: test
         instance_type: t2.micro
         image: "{{ ami_id }}"
         wait: true
         exact_count: 5
         count_tag:
            Name: Demo
         instance_tags:
            Name: Demo
      register: ec2

   - name: Add all instance public IPs to host group
     add_host: hostname={{ item.public_ip }} groups=ec2hosts
     loop: "{{ ec2.instances }}"

- hosts: ec2hosts
  name: configuration play
  user: ec2-user
  gather_facts: true

  tasks:

     - name: Check NTP service
       service: name=ntpd state=started
```

creates 5 instances on AWS (destroying them if there are more than 5 with the appropriate tag, creating less if there are already some). It then adds them to the inventory in the `ec2hosts` group using the results. It then checks that NTP is started on all of them.

### Patterns

Host patterns specify which hosts from the inventory to run against. 

`*` and `all` are equivalent. 

`host1.example.com:host2:example.com` specifies both hosts. Host and group names also work. 

Can include wildcards in host names, group names, or IP addresses, e.g. `192.168.7.*` or `*.example.com`.

Can negate groups `!group_to_exclude` or do intersections: `group1:&group2` is intersection of `group1` and `group2`. 

Can also subscript groups: `webservers[0]` is the first host in `webservers`, `webservers[-1]` is the last, `webservers[2:4]` is the third and fourth, `webservers[1:]` is the second onwards etc.

Patterns that start with `~` are regular expressions.

Patterns that start with `@` are the names of files to read hosts from.

Passing `--limit pattern` to `ansible-playbook` limits it to hosts in pattern that are also in its host list.

## Roles and Playbooks

### Playbooks

Playbooks contain (a list of) plays, which include which hosts/groups etc to run on and tasks. Specified in [YAML](#yaml)

For example:

```
- hosts: webservers
  remote_user: root
  tasks:
    - name: test connection
      ping:
      remote_user: yourname
```

Tasks or have human readable names (description), and a module name with arguments. 

Tasks or plays can have a `remote_user` to set the user to login with, `become: yes` to become root, `become_user: myuser` to become another user (with `become: yes` as well), `become_method: su` for different methods. `become_flags` passes arguments to `su` or `sudo`, for example `become_flags: '-s /bin/sh'` for a user with `/sbin/nologin` as their shell. `ansible_become`, `ansible_become_method`, `ansible_become_user` are the equivalent variables to set for hosts. `ansible_become_pass` can store the password (probably using vault).

Warning: If becoming a user other than root, what is executed becomes visible to others (to read, not write) in /tmp. 

Plays can also have `gather_facts: False` to not run the fact gathering module.

Can use variables in names and tasks, e.g. {{ vhost }}.

### Running

Run with `ansible-playbook playbook.yml`. `-C` or `--check` just shows what would happen. `-D` or `--diff` shows diffs for small files (can combine with `-C`). `--syntax-check` checks syntax.

If `check_mode: yes` is set for a task, it is always run in check mode (so does not make changes). If `check_mode: no` is set for a task, it is run in normal mode, even when the playbook is run in check mode.

`ansible_check_mode` is set to true when in check mode.

Plays can also have an order e.g. `order: sorted` for any of 

* `inventory` (the default, the order of hosts in the inventory)
* `reverse_inventory`
* `sorted` (alphabetical)
* `reverse_sorted`
* `shuffle` (random)

`any_errors_fatal: True` on a play, playbook execution will stop on any errors.

`--start-at-task="task name"` starts at a task named `task name`.

`--step` asks before running each task. `y` runs it, `n` skips it, `c` stops asking and says `y` from now on.

#### Running locally

Use 

```
- hosts: 127.0.0.1
  connection: local
```

to run just locally, or `ansible-playbook playbook.yml --connection=local` with `hosts: 127.0.0.1`

#### Strategy

By default, tasks in a play are executed in order, because the default `strategy` is `linear`, but you can change this by setting `strategy: free` to make one host run until the end of the play before going on to the next. 

`strategy: debug` runs the debugger. 

Strategies are plug-ins.

#### Running asynchronously

To make a task run asynchronously, add `async: <time_limit>` where `<time_limit>` is in seconds. If omitted, the default is to run synchronously. You can specify how often to poll for 
status with `poll: <period>` where `<period>` is in seconds. The default poll period is 10 seconds. 

```
---
- hosts: all
  remote_user: root
  tasks:
  - name: simulate long running op (15 sec), wait for up to 45 sec, poll every 5 sec
    command: /bin/sleep 15
    async: 45
    poll: 5
```

You can avoid waiting for a task to be completed by setting `poll: 0`. This is useful for checking on a task in a later task:

```
---
# Requires ansible 1.8+
- name: 'YUM - async task'
  yum:
    name: docker-io
    state: installed
  async: 1000
  poll: 0
  register: yum_sleeper
- name: 'YUM - check on async task'
  async_status:
    jid: "{{ yum_sleeper.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 30
```

The following uses the `batch` filter to run several tasks asynchronously in batches.

```
#####################
# main.yml
#####################
- name: Run items asynchronously in batch of two items
  vars:
    sleep_durations:
      - 1
      - 2
      - 3
      - 4
      - 5
    durations: "{{ item }}"
  include_tasks: execute_batch.yml
  loop:
    - "{{ sleep_durations | batch(2) | list }}"

#####################
# execute_batch.yml
#####################
- name: Async sleeping for batched_items
  command: sleep {{ async_item }}
  async: 45
  poll: 0
  loop: "{{ durations }}"
  loop_control:
    loop_var: "async_item"
  register: async_results

- name: Check sync status
  async_status:
    jid: "{{ async_result_item.ansible_job_id }}"
  loop: "{{ async_results.results }}"
  loop_control:
    loop_var: "async_result_item"
  register: async_poll_results
  until: async_poll_results.finished
  retries: 30
```

#### Rebooting

The following works for rebooting a host:

```
  handlers:
    - name: Reboot device
      command: shutdown -r +1
      async: 0
      poll: 0
      ignore_errors: true
      register: restarted
      notify: Wait for reboot to be done
    - name: Wait for reboot to be done
      become: no
      local_action:
        module: wait_for
        host: "{{ inventory_hostname }}"
        delay: 60
        state: started
        timeout: 240
      when: restarted.changed
```

This uses `+1` as the time argument to shutdown because doing it immediately causes an error that isn't ignored for some reason.

Using the `removes: /var/run/reboot-required` parameter to `command` to remove `/var/run/reboot-required` and not run if it isn't there allows you to reboot only when a package update by apt requires a reboot.

### Include and Import

`include*` statements are dynamic, including the file when needed, with the variables etc available. `import*` are static. 

Dynamic tasks cannot be listed, started at, or have handlers triggered by tasks outside the include. Static tasks cannot be used in loops or use host/group vars.

Commands are `include_playbook`, `include_role`, `include_tasks`, `import_playbook`, `import_role` and `import_tasks`. 

```
---
- hosts: webservers
  tasks:
  - include_role:
      name: example
  - include_tasks: wordpress.yml
    vars:
      wp_user: timmy
  handlers:
  - include_tasks: handlers.yml
- include_playbook: another_set_of_plays.yml
```

One place where the distinction is important is when an included file modifies a variable used in a conditional e.g.

```
# include a file to define a variable when it is not already defined

# main.yml
- include_tasks: other_tasks.yml
  when: x is not defined

# other_tasks.yml
- set_fact:
    x: foo
- debug:
    var: x
```

Will print the value of `x` whatever, whereas `import_tasks` will not print it unless it is not already set, as the expression is evaluated just once before import.

### Searching for a template

```
- name: template a file
  template:
      src: "{{ item }}"
      dest: /etc/myapp/foo.conf
  loop: "{{ query('first_found', { 'files': myfiles, 'paths': mypaths}) }}"
  vars:
    myfiles:
      - "{{ansible_distribution}}.conf"
      -  default.conf
    mypaths: ['search_location_one/somedir/', '/opt/other_location/somedir/']
```

Will search multiple directories for a list of file names, and use the first found.

### Tags

Tags can be added to tasks (and plays, roles, blocks, include_tasks, but they just apply to all tasks in these) to control whether those tasks are run using `--tags` or `--skip-tags` command-line options.

```
tasks:
    - yum:
        name: "{{ item }}"
        state: installed
      loop:
         - httpd
         - memcached
      tags:
         - packages
    - template:
        src: templates/src.j2
        dest: /etc/foo.conf
      tags: configuration
```

Tags are inherited by dependant roles from a role.

The `always` tag causes a task to be run unless the `always` tag is excluded. 

The `never` tag causes a plug to not be run unless it is specifically requested by specifically requesting the `never` tag or another tag it is tagged with. 

```
tasks:
  - debug: msg='{{ showmevar }}'
    tags: [ 'never', 'debug' ]
```

**is** run when running `ansible-playbook playbook.yml --tags debug`.

The tags `all`, `untagged` and `tagged` can be used to specify all tasks (as normal running), all tagged tasks, or all untagged tasks.

### Handlers

You can add `notify: restart_apache` for example to notify the `restart_apache` handler. It is then run after the tasks in a play are all done, once, if notified. 

Handlers are defined as with tasks, but are defined in the `handlers` block of the play. 

```
handlers:
    - name: restart memcached
      service:
        name: memcached
        state: restarted
    - name: restart apache
      service:
        name: apache
        state: restarted
```

Can listen to generic topic strings which can then be notified.

The `meta: flush_handlers` task will flush all pending handlers.

Handlers will not be run for hosts where a task has failed. To change this, use `--force-handlers` on the command-line, `force_handlers: True` in a play, or `force_handlers = True` in the configuration.

### Roles

Roles are a convenient way to make re-useable playbooks. They must have at least one of the following directories, each with a `main.yml`

* `tasks` - main list of tasks to be executed.
* `handlers` - handlers to be used by this role or outside it.
* `defaults` - default variables for the role.
* `vars` - other variables for the role.
* `files` - files to be deployed by the role.
* `templates` - templates to be deployed via the role.
* `meta` - metadata. 

```
# roles/example/tasks/main.yml
- name: added in 2.4, previously you used 'include'
  import_tasks: redhat.yml
  when: ansible_os_platform|lower == 'redhat'
- import_tasks: debian.yml
  when: ansible_os_platform|lower == 'debian'

# roles/example/tasks/redhat.yml
- yum:
    name: "httpd"
    state: present

# roles/example/tasks/debian.yml
- apt:
    name: "apache2"
    state: present
```

Adding `allow_duplicates: true` to `meta/main.yml` of a role allows it to be run more than once if included with the same variables.

Adding a `dependencies` list to `meta/main.yml` allows you to depend on other roles. 

```
- dependencies:
  - role: common
    vars:
      foo: bar
  - role: apache
```

Dependant roles that are identical for two different roles will only be run once unless `allow_duplicates: true` is set in the role that is the dependancy. Dependant roles are run first.

You can use variables to fill the values of parameters for dependant roles.

### Variables

Variable names can contain letters, numbers and underscores only. They must start with a letter.

YAML dictionaries can be references with either subscript or dot notation.

```
foo:
  field1: one
  field2: two
```

```
foo['field1']
foo.field1
```

Use the subscript notation to avoid collision with python names.

Variables can be defined in a `vars` section in a play, or from a file:

```
- hosts: webservers
  vars:
    http_port: 80
  vars_files:
    - /var/file/path.yml
```

vars_files are YAML files with just a dictionary of names to values.

You can supply a list of files one one line, and the first existing one will be used, e.g.

```
vars_files:
  - [ "vars/{{ ansible_os_family}}.yml", "vars/os_defaults.yml" ]
```

On CentOS, `vars/RedHat.yml` will be tried first, then `vars/os_defaults.yml` if that doesn't exist, etc.

Variables can be used in both playbooks and templates, as well as for loops and conditionals in templates (do not use Jinja2 loops or conditionals in playbooks).

Variables can be registered by a task for later tasks by adding `register: variable_name`. `variable_name` will then contain the output of the task. e.g.

```
- name: test play
  hosts: all
  tasks:
    - shell: cat /etc/motd
      register: motd_contents
    - shell: echo "motd contains the word hi"
      when: motd_contents.stdout.find('hi') != -1
```

(`my_file.stdout_lines` and `my_file.stdout.split()` are equivalent, and usable for lines in a loop.)

`hostvars`, `group_names`, groups` and `environment` are all reserved names. 

`hostvars` is a dictionary of all hosts and their hostvars (so `hostvars['host1.example.com']['ansible_distribution']` for example). It is filled as they are contacted with facts, but always contains hostvars.

`group_names` is a list of all groups the current host is in.

`groups` is a list of all hosts and groups (so, e.g. `groups['webservers']).

```
{% for host in groups['app_servers'] %}
   {{ hostvars[host]['ansible_eth0']['ipv4']['address'] }}
{% endfor %}
```

lists all IP addresses of hosts in the `app_servers` group.

Can pass extra variables with the `-e` option, in JSON, YAML or key=value format. key-value format are always strings. Can also use `-e @some_vars.json` for JSON or YAML.

`ansible_check_mode` is set to True when in check (`-C`) mode.

#### Prompting for variables

You can use `vars_prompt` to prompt for variables.

```
---
- hosts: all
  remote_user: root

  vars:
    from: "camelot"

  vars_prompt:
    - name: "name"
      prompt: "what is your name?"
    - name: "quest"
      prompt: "what is your quest?"
    - name: "favcolor"
      prompt: "what is your favorite color?"
      default: "blue"
```

Adding `private: yes` to a prompt hides input.

If [Passlib](https://passlib.readthedocs.io/en/stable/) is installed, you can use it to encrypt input so that it can be used in a password file. 

```
vars_prompt:

  - name: "my_password2"
    prompt: "Enter password2"
    private: yes
    encrypt: "sha512_crypt"
    confirm: yes
    salt_size: 7
```

Either of `salt`, to supply salt, or `salt_size`, to generate it, can be used.

#### Facts

Facts are gathered unless `gather_facts: no` is set for the play. They can be viewed by running `ansible hostname -m setup` for `hostname`. They are then just variables that can be used as normal. 

You can also supply facts to ansible from INI, JSON or YAML files in `/etc/ansible/facts.d/*.fact`. These will then be in `ansible_local['filename'][section][name]`. INI file keys are converted to lowercase.

Facts can be cached. [See this section of documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#fact-caching).

You can [write a module](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules.html#developing-modules) to gather custom facts, e.g.

```
tasks:
    - name: gather site specific fact data
      action: site_facts
    - command: /usr/bin/thingy
      when: my_custom_fact_just_retrieved_from_the_remote_system == '1234'
```

### Module defaults

You can specify default values for modules in a play, block or task.

```
- hosts: localhost
  module_defaults:
    file:
      owner: root
      group: root
      mode: 0755
  tasks:
    - file:
        state: touch
        path: /tmp/file1
    - file:
        state: touch
        path: /tmp/file2
    - file:
        state: touch
        path: /tmp/file3
```

Tasks which specify them will override.

Setting an empty dictionary removes defaults

```
- file:
    state: touch
    path: /tmp/file1
  module_defaults:
    file: {}
```

Defaults set that apply to a role (when using `include_role` or `import_role`) apply to the role, which is likely to be problematic).

### Environment

Environment variables can be set per task or play with the `environment` keyword.

```
- hosts: all
  remote_user: root
  tasks:
    - apt: name=cobbler state=installed
      environment:
        http_proxy: http://proxy.example.com:8080
```

They can also use variables (could be in `group_vars`).

```
- hosts: all
  remote_user: root
  # here we make a variable named "proxy_env" that is a dictionary
  vars:
    proxy_env:
      http_proxy: http://proxy.example.com:8080
  tasks:
    - apt: name=cobbler state=installed
      environment: "{{proxy_env}}"
```

`environment` does not work for Windows.

### Filters

Filters are a feature of Jinja2. See [Jinja2 built-in filters](http://jinja.pocoo.org/docs/templates/#builtin-filters). 

#### JSON and YAML

```
{{ some_variable | to_json }}
{{ some_variable | to_yaml }}
{{ some_variable | to_nice_json }}
{{ some_variable | to_nice_yaml }}
{{ some_variable | to_nice_json(indent=2) }}
{{ some_variable | to_nice_yaml(indent=8) }}
{{ some_variable | from_json }}
{{ some_variable | from_yaml }}
```

are useful for converting to/from JSON/YAML.

`json_query('domain.server[*].name')` would give the ['name'] attribute of all elements of input['domain']['server'] list. Can also use '...[?cluster==''cluster1''] for 
elements of a list where the cluster attribute is cluster1. Also `domains.servers[*]{name: name, port: port}` gives a map with name and port keys equal to the name and port attributes 
of the elements of server.

#### Defaults and mandatory

By default, variables must be defined when used. This can be switched off in ansible.cfg. The `mandatory` filter then causes an error if the variable is undefined. 

The `default` filter can be used to provide a default, e.g. `{{ some_variable | default(5) }}`. `default` accepts a second parameter, which, if `true`, uses the default when the variable is an empty string. The special `default(omit)` argument undefines the variable by default, so you can use the default that is there without it set.

You can also use `or` logic with `omit`: `“{{ foo | default(None) | some_filter or omit }}”`. 

The default filter can be used to skip a loop by providing a default empty list.

```
- command: echo {{ item }}
  loop: "{{ mylist|default([]) }}"
  when: item > 5
```

#### Containers

`min`, `max` and `flatten` (or `flatten(levels=1)` to flatten just one level) work with lists.

`unique` on a list gets a list of just unique values.

`{{ list1 | union(list2) }}`, `{{ list1 | intersect(list2) }}`, `{{ list1 | difference(list2) }}` and `{{ list1 | symmetric_difference(list2) }}` do set ops on lists.

`join(', ')` joins a list to a string.

`{{ dict | dict2items }}` turns 

```
tags:
  Application: payment
  Environment: dev
```

to

```
- key: Application
  value: payment
- key: Environment
  value: dev
```

`{{ {'a': 1, 'b': 2} | combine({'b': 3}) }}` produces `{'a':1, 'b': 3}`. The `recursive=True` argument causes dictionaries in dictionaries to be combined. 

`map('extract', list)` extracts the elements of a list using a list of indices, so  `{{ [0,2]|map('extract', ['x','y','z'])|list }}` produces `['x', 'z']`.

It can also take a third argument, the key to look up in the resulting dict: `{{ groups['x']|map('extract', hostvars, 'ec2_ip_address')|list }}` extracts the `ec2_ip_address` of hosts in group `x`.

#### Subelements

`subelements` makes products of objects, and elements of a property of them, for each value in the property. i.e.

`{{ users|subelements('groups', skip_missing=True) }}`

turns

```
users:
  - name: alice
    authorized:
      - /tmp/alice/onekey.pub
      - /tmp/alice/twokey.pub
    groups:
      - wheel
      - docker
  - name: bob
    authorized:
      - /tmp/bob/id_rsa.pub
    groups:
      - docker
```

into 

```
-
  - name: alice
    groups:
      - wheel
      - docker
    authorized:
      - /tmp/alice/onekey.pub
  - wheel
-
  - name: alice
    groups:
      - wheel
      - docker
    authorized:
      - /tmp/alice/onekey.pub
  - docker
-
  - name: bob
    authorized:
      - /tmp/bob/id_rsa.pub
    groups:
      - docker
  - docker
```

#### Random

`"{{ ['a','b','c']|random }}"` selects a random element from a list.

`"{{ 60 |random}}` selects a random number [0,60[.

Arguments `start` sets min, `step` sets step size, `seed` sets seed.

`{{ 101 |random(start=1, step=10, seed=inventory_hostname) }}`

`shuffle` can shuffle a list, again using `seed`.

#### Math

`log` for natural log. `log(10)` for base 10, `pow(5)` for power, `root(3)` for (cube) root.

#### IPs

`ipaddr` checks for a valid IP. `ipv4` and `ipv6` for IPv4, IPv6. `ipaddr('address')` gets the address from something like `192.168.7.0/24`.

`parse_cli` can be used to parse the output of commands from the CLI of many network devices (with spec files which tell it how to convert it to JSON data). `parse_xml` can do the same for XML output.

#### Cryptographic Hashes

`hash('sha1')`, `hash('md5')` etc produce hashes of data. 

`password_hash('sha512', 'mysecretsalt')` for passwords. `{{ 'secretpassword'|password_hash('sha512', 65534|random(seed=inventory_hostname)|string) }}` is idempotent.

#### Comments

The comment filter can produce comments in various languages:

```
{{ "C style" | comment('c') }}
{{ "C block style" | comment('cblock') }}
{{ "Erlang style" | comment('erlang') }}
{{ "XML style" | comment('xml') }}
```

#### URLs

The `urlsplit` filter extracts the fragment, hostname, netloc, password, path, port, query, scheme, and username from an URL. With no arguments, returns a dictionary of all the fields.

```
{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('hostname') }}
# => 'www.acme.com'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('netloc') }}
# => 'user:password@www.acme.com:9000'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('username') }}
# => 'user'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('password') }}
# => 'password'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('path') }}
# => '/dir/index.html'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('port') }}
# => '9000'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('scheme') }}
# => 'http'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('query') }}
# => 'query=term'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit('fragment') }}
# => 'fragment'

{{ "http://user:password@www.acme.com:9000/dir/index.html?query=term#fragment" | urlsplit }}
# =>
#   {
#       "fragment": "fragment",
#       "hostname": "www.acme.com",
#       "netloc": "user:password@www.acme.com:9000",
#       "password": "password",
#       "path": "/dir/index.html",
#       "port": 9000,
#       "query": "query=term",
#       "scheme": "http",
#       "username": "user"
#   }
```

#### Regex

`regex_search` searches for a regex in the input. 

`regex_findall` returns a list of all matches. 

`regex_replace` replaces the first with second. 

`regex_escape` escapes regex special characters.

#### Paths

`basename` gives the last component of a path. `win_basename` for Windows. `win_splitdrive` produces a pair, drive and path.

`dirname` gives the directory part of a path. `win_dirname` for Windows.

`expanduser` expands user home dir shortcuts.

`expandvars` expands a path with environment variables in it.

`realpath` give the canonical path of a link.

`relpath('/etc')` etc give the relative path with a given start-point.

`splitext` splits the file name and extension.

#### Datetime

`to_datetime` converts a string to a datetime using the format string argument (can then do `.total_seconds()` etc on differences between them etc).

`strftime` formats a number of seconds since the epoch as an argument in the format provided as input.

#### Other

`quote` quotes a string for use in a shell commend.

`ternery` takes two arguments and returns the first if the input is true.

`first` and `last` give first and last of a sequence.

`b64decode` and `b64encode` decode and encode base64 strings.

`to_uuid` generates a UUID based on input.

`bool` turns "True" into a bool True etc.

`int` turns a string into an int.

`zip` gives a pair of lists by zipping the input and the argument list.

`type_debug` gives the type of input.

### Tests

Tests are expressions of the form `value is test_name`. There are [many built-in tests in Jinja2](http://jinja.pocoo.org/docs/templates/#builtin-tests).

Tests can be used with processing filters like `map()` and `select()`. 

#### Variables

`my_variable is defined` is true only if `my_variable` is defined.

`my_variable is undefined` is true only when `my_variable` is undefined.

#### Regex

Use `match("pattern")` to check for a regex match of a string against a pattern.

`search` to search for a pattern in the input.

#### Version

`{{ ansible_distribution_version is version('12.04', '>=') }}` will check the `ansible_distribution_version` is greater or equal to 12.04.

#### Group theory tests

`a is subset(b)` tests whether a is a subset of b. `superset` for superset.

#### Paths

`directory`, `file`, `link`, `exists`, `abs`, `same_file(other_path)`, `mount` tests paths.

#### Task results

`failed`, `changed`, `succeeded`, `sucess`, `skipped` test task results.

### Lookups

Lookups are plugins used to look-up info from outside data sources. They are executed on the local/control machine. Executed in directory of role or play, as opposed to tasks and plays which are in the directory of the executed script.

Passing `wantlist=True` returns a list you can use in Jinja2 for loops.

Some lookup arguments are passed to the shell, so escape them with `| quote` and be careful of untrusted values.

They can be used with variables, e.g.

```
vars:
  motd_value: "{{ lookup('file', '/etc/motd') }}"
tasks:
  - debug:
      msg: "motd value is {{ modt_value }}"
```

`query` can lookup in a key-value store. e.g.

```
- command: echo {{ item.key }}
  loop: "{{ query('dict', mydict|default({})) }}"
  when: item.value > 5
```

### Conditionals

See also [Jinja2 documentation on how conditionals can be used in Jinja expressions](http://jinja.pocoo.org/docs/dev/templates/#comparisons).

The when attribute of a task contains a raw Jinja2 expression without the curly braces and the task is skipped if it is false. e.g.

```
tasks:
  - name: "shut down CentOS 6 and Debian 7 systems"
    command: /sbin/shutdown -t now
    when: (ansible_distribution == "CentOS" and ansible_distribution_major_version == "6") or
          (ansible_distribution == "Debian" and ansible_distribution_major_version == "7")
```

Multiple conditions can be supplies, and all need to be true (and):

```
tasks:
  - name: "shut down CentOS 6 systems"
    command: /sbin/shutdown -t now
    when:
      - ansible_distribution == "CentOS"
      - ansible_distribution_major_version == "6"
```

When combined with loops, the when is evaluated for each iteration:

```
tasks:
    - command: echo {{ item }}
      loop: [ 0, 2, 4, 6, 8, 10 ]
      when: item > 5
```

### Loops

Inside a loop, registered variables will be the result from this iteration. In other tasks, they will contain a `results` attribute that is a list of these.

#### Loop

Use `loop` to do a task for each element in a list, e.g.

```
- name: add several users
  user:
    name: "{{ item }}"
    state: present
    groups: "wheel"
  loop:
     - testuser1
     - testuser2
```

Can also use already defined variables, e.g. from a vars section: `loop: "{{ somelist }}"`

Some modules can accept lists directly, e.g. `apt`:

```
- name: Install packages.
  apt:
    name: "{{ list_of_packages }}"
    state: present
```

#### Looping over inventory

You can use `groups` or `ansible_play_batch` as loop variables to loop over specific hosts, e.g.

```
# show all the hosts in the inventory
- debug:
    msg: "{{ item }}"
  loop: "{{ groups['all'] }}"

# show all the hosts in the current play
- debug:
    msg: "{{ item }}"
  loop: "{{ ansible_play_batch }}"
```

You can also use the `inventory_hostnames` plug-in to do full pattern matching:

```
# show all the hosts matching the pattern, i.e. all but the group www
- debug:
    msg: "{{ item }}"
  loop: "{{ query('inventory_hostnames', 'all!www') }}"
```

#### Loop var

You can loop over included tasks (but not playbooks), but this means you can have loops in loops. They would overwrite the `item` variable (which causes an error) unless you specify a different variable for the loop variable with `loop_control` and `loop_var`, e.g.

```
# main.yml
- include_tasks: inner.yml
  loop:
    - 1
    - 2
    - 3
  loop_control:
    loop_var: outer_item

# inner.yml
- debug:
    msg: "outer item={{ outer_item }} inner item={{ item }}"
  loop:
    - a
    - b
    - c
```

#### Label

To make it clearer what item you are on, if using complex data structures as the loop item, the `label` directive in `loop_control`:

```
- name: create servers
  digital_ocean:
    name: "{{ item.name }}"
    state: present
  loop:
    - name: server1
      disks: 3gb
      ram: 15Gb
      network:
        nic01: 100Gb
        nic02: 10Gb
        ...
  loop_control:
    label: "{{ item.name }}"
```

#### Pause

The `pause` `loop_control` directive allows you to pause for a set number of seconds between iterations.

```
- name: create servers, pause 3s before creating next
  digital_ocean:
    name: "{{ item }}"
    state: present
  loop:
    - server1
    - server2
  loop_control:
    pause: 3
```

#### Index

You can set an index variable to count iterations with the `index_var` `loop_control` directive:

```
- name: count our fruit
  debug:
    msg: "{{ item }} with index {{ my_idx }}"
  loop:
    - apple
    - banana
    - pear
  loop_control:
    index_var: my_idx
```

#### Until

The `until` keyword allows you to do something until a condition is true, `retries` specifies the number of retries (3 by default if not specified) and `delay` specifies the delay in seconds between attempts (5 by default if not present).

```
- shell: /usr/bin/foo
  register: result
  until: result.stdout.find("all systems go") != -1
  retries: 5
  delay: 10
```

`retries` is always 1 if `until` is not defined.

If the `until` condition is never true, the result of the whole task is `failed`.

#### With_X

Before Ansible 2.5, the recommended way to do loops is with the `with_X` keywords

##### with_list

```
- name: with_list
  debug:
    msg: "{{ item }}"
  with_list:
    - one
    - two

- name: with_list -> loop
  debug:
    msg: "{{ item }}"
  loop:
    - one
    - two
```

##### with_items

```
- name: with_items
  debug:
    msg: "{{ item }}"
  with_items: "{{ items }}"

- name: with_items -> loop
  debug:
    msg: "{{ item }}"
  loop: "{{ items|flatten(levels=1) }}"
```

##### with_indexed_items

```
- name: with_indexed_items
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  with_indexed_items: "{{ items }}"

- name: with_indexed_items -> loop
  debug:
    msg: "{{ index }} - {{ item }}"
  loop: "{{ items|flatten(levels=1) }}"
  loop_control:
    index_var: index
```

##### with_flattened

```
- name: with_flattened
  debug:
    msg: "{{ item }}"
  with_flattened: "{{ items }}"

- name: with_flattened -> loop
  debug:
    msg: "{{ item }}"
  loop: "{{ items|flatten }}"
```

##### with_together

```
- name: with_together
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  with_together:
    - "{{ list_one }}"
    - "{{ list_two }}"

- name: with_together -> loop
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  loop: "{{ list_one|zip(list_two)|list }}"
```

##### with_dict

```
- name: with_dict
  debug:
    msg: "{{ item.key }} - {{ item.value }}"
  with_dict: "{{ dictionary }}"

- name: with_dict -> loop (option 1)
  debug:
    msg: "{{ item.key }} - {{ item.value }}"
  loop: "{{ dictionary|dict2items }}"

- name: with_dict -> loop (option 2)
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  loop: "{{ dictionary|dictsort }}"
```

##### with_sequence

```
- name: with_sequence
  debug:
    msg: "{{ item }}"
  with_sequence: start=0 end=4 stride=2 format=testuser%02x

- name: with_sequence -> loop
  debug:
    msg: "{{ 'testuser%02x' | format(item) }}"
  # range is exclusive of the end point
  loop: "{{ range(0, 4 + 1, 2)|list }}"
```

##### with_subelements

```
- name: with_subelements
  debug:
    msg: "{{ item.0.name }} - {{ item.1 }}"
  with_subelements:
    - "{{ users }}"
    - mysql.hosts

- name: with_subelements -> loop
  debug:
    msg: "{{ item.0.name }} - {{ item.1 }}"
  loop: "{{ users|subelements('mysql.hosts') }}"
```

##### with_nested/with_cartesian

```
- name: with_nested
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  with_nested:
    - "{{ list_one }}"
    - "{{ list_two }}"

- name: with_nested -> loop
  debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  loop: "{{ list_one|product(list_two)|list }}"
```

##### with_random_choice

```
- name: with_random_choice
  debug:
    msg: "{{ item }}"
  with_random_choice: "{{ my_list }}"

- name: with_random_choice -> loop (No loop is needed here)
  debug:
    msg: "{{ my_list|random }}"
  tags: random
```

### Blocks

Blocks can be used to group tasks, and for exception-like error handling. Blocks can be used in place of tasks, and contain several tasks. Most directives can be applied to blocks instead of tasks, making them apply to all tasks in the block (rather than to the block itself). 

```
 tasks:
   - name: Install Apache
     block:
       - yum:
           name: "{{ item }}"
           state: installed
         with_items:
           - httpd
           - memcached
       - template:
           src: templates/src.j2
           dest: /etc/foo.conf
       - service:
           name: bar
           state: started
           enabled: True
     when: ansible_distribution == 'CentOS'
     become: true
     become_user: root
```

Here the `when` applies separately to each task.

#### Error handling

Tasks in the `rescue` section of a block run whenever an error happens in a block. Tasks in the `always` section run either way. Unless there is an error in the `rescue` section, the `max_fail_percentage` or `any_errors_fatal` aren't triggers, but the error is counted in the playbook statistics.

```
 tasks:
 - name: Attempt and graceful roll back demo
   block:
     - debug:
         msg: 'I execute normally'
     - command: /bin/false
     - debug:
         msg: 'I never execute, due to the above task failing'
   rescue:
     - debug:
         msg: 'I caught an error'
     - command: /bin/false
     - debug:
         msg: 'I also never execute :-('
   always:
     - debug:
         msg: "This always executes"
```

`ansible_failed_task` is set to the task that failed causing the `rescue` block to be run (so, `ansible_failed_task.name` is the task name). 

`ansible_failed_result` is the result of the failed task (as if it had used `register`).

### Changed when

The `changed_when` parameter can be used to control if a task is considered to have caused a change. 

```
- shell: echo "{{ item }}"
  loop:
    - one
    - two
  register: echo
  changed_when: echo.stdout != "one"
```

### Failing tasks

The `fail` parameter can make a task (most useful with a conditional) fail with a message (`msg`):

```
- name: Fail if return code is not 0
  fail:
    msg: "The command ({{ item.cmd }}) did not have a 0 return code"
  when: item.rc != 0
  loop: "{{ echo.results }}"
```

`fail_when` can be used to control what causes a task to be regarded as failed. e.g.

```
- name: Fail task when the command error output prints FAILED
  command: /usr/bin/example-command -x -y -z
  register: command_result
  failed_when: "'FAILED' in command_result.stderr"
```

### Delegating

Using the `delegate_to`, most tasks (except `add_host`, `include`, `debug` etc which run on the control machine) can be run on a machine other than the one being processed.

```
---

- hosts: webservers
  serial: 5

  tasks:

  - name: take out of load balancer pool
    command: /usr/bin/take_out_of_pool {{ inventory_hostname }}
    delegate_to: 127.0.0.1

  - name: actual steps would go here
    yum:
      name: acme-web-stack
      state: latest

  - name: add back to load balancer pool
    command: /usr/bin/add_back_to_pool {{ inventory_hostname }}
    delegate_to: 127.0.0.1
```

The following works for delegating to localhost

```
tasks:
  - name: take out of load balancer pool
    local_action: command /usr/bin/take_out_of_pool {{ inventory_hostname }}
```

`ansible_host` is the host delegated to.

If `delegate_facts: True` is set, facts gathered are assigned to the delegated host, not the one the task was run for.

### Run once

To run a task just once, for each batch of hosts, use `run_once: True`. This will then run only once and reuse the result for the rest of the batch. 

To make it run truly once only, regardless of `serial`, use `when: inventory_hostname == ansible_play_hosts[0]`. The `when` clause for the `run_once` will only be evaluated for the first host, so it may be run zero times.

### Debugguing

The `debugger` keyword can be used on plays, roles and tasks. It can be set to the following values:

* `always` - always invoke the debugger, regardless of the outcome
* `never` - never invoke the debugger, regardless of the outcome.
* `on_failed` - invoke the debugger if a task fails.
* `on_unreachable` - invoke the debugger if a host was unreachable.
* `on_skipped` - invoke the debugger if the task is skipped.

You can also set `enable_task_debugger = True` in `[defaults]` in the configuration, `ansible.cfg`, or set `ANSIBLE_ENABLE_TASK_DEBUGGER=True` in the environment, or set `strategy = debug` in the `[defaults]` section of the configuration, or set `ANSIBLE_STRATEGY=debug` in the environment.

See [the documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html#available-commands) for the available commands in the debugger.

### Best practices

`site.yml` is the usual name for the master playbook. Have it just import all the playbooks for sets of hosts that map those hosts to roles. It may also include other playbooks that do some specific tasks that acts on different sets of hosts.

Do not use a static inventory if there is another source for truth for it (e.g. cloud hosts).

Separate production and staging instances using different inventory files, or using tags on hosts, e.g. EC2 instance tag `environment:production` then the group `ec2_tag_environment_production` will exist.

Use `group_vars/all` for universally true variables.

Use `serial` for rolling updates.

Use `group_by` to run things for specific OSes.

```
---

 # talk to all hosts just so we can learn about them
 - hosts: all
   tasks:
     - group_by:
         key: os_{{ ansible_distribution }}

 # now just on the CentOS hosts...

 - hosts: os_CentOS
   gather_facts: False
   tasks:
     - # tasks that only happen on CentOS go here
```

Groups from `group_by` can still use `group_vars`.

Always name tasks.

Use a `vars` and a `vault` file in `group_vars` directories, and, for all sensitive variables, for a variable names `p` set `p` to the value of `vault_p` in `vars` and define `vault_p` in `vault`. 

## Python versions

Ansible uses Jinja2 and Python, so can depend on Python version. One example is the result of `dict.keys()`, `dict.values()` and `dict.items()`, which is a list in Python2, but has to be passed to the `| list` filter in Python3 to use as a list, rather than a string. e.g.

```
vars:
  hosts:
    testhost1: 127.0.0.2
    testhost2: 127.0.0.3
tasks:
  - debug:
      msg: '{{ item }}'
    # Only works with Python 2
    #loop: "{{ hosts.keys() }}"
    # Works with both Python 2 and Python 3
    loop: "{{ hosts.keys() | list }}"
```

## Ansible Console

`ansible-console` provides a REPL console for running ad-hoc tasks against a set of hosts.

## Ansible Doc

`ansible-doc debug` shows documentation for debug module. It works for most modules. `-l` lists modules. `-F` lists files. `-s` shows usage snippet.

## Ansible Galaxy

`ansible-galaxy` is used to interact with [Ansible Galaxy](https://docs.ansible.com/ansible/latest/reference_appendices/galaxy.html). 

`ansible-galaxy init role_name` creates defaults (including a .travis.yml). Use `ansible-galaxy init --container-enabled role_name` to get a default role suitable for containers.

## Ansible Vault

Used to encrypt variables passed to ansible via `group_vars/`, `host_vars/`, variables loaded with `include_vars` or `vars_file`, or passed to the playbook with `-e @ansible_vars.yaml` or `-e ansible_vars.json`.

`ansible-vault {encrypt|edit|view|...} [options] vaultfile.yml`

* `create` creates a file, after asking for a password, then edits it with $EDITOR.
* `edit` edits a file with $EDITOR.
* `rekey` changes a password.
* `encrypt` encrypts a plain-text file.
* `decrypt` decrypts a file to plain-text.
* `view` view a file using $PAGER.
* `encrypt_string` encrypts a string value (passed as an argument) for the key passed with `--name`

Secrets can have a vault-id associated with them, so different secrets can be encrypted with different passwords.

Setting `--vault-id @prompt` asks for the vault password (or, for just asking for a particular ID, use `--vault-id dev@prompt` to prompt for the `dev` vault-id password). To use a passwordfile for a particular vault-id, use `--vault-id dev@dev-password` to use the file `dev-password` for the password for the vault-id `dev`.

Setting `--vault-password-file` to a script which prints the password, which is encrypted with GPG, to the standard out, works. This can be set in [ansible.cfg](#ansible-configuration-file).

You can also set the `ANSIBLE_VAULT_PASSWORD_FILE` environment variable.

To encrypt just a single variable in a variable file, you can use `!vault |` and then follow with the encrypted value (which will be multi-line).

```
notsecret: myvalue
mysecret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653236336462626566653063336164663966303231363934653561363964363833313662
          6431626536303530376336343832656537303632313433360a626438346336353331386135323734
          62656361653630373231613662633962316233633936396165386439616533353965373339616234
          3430613539666330390a313736323265656432366236633330313963326365653937323833366536
          34623731376664623134383463316265643436343438623266623965636363326136
other_plain_text: othervalue
```

Use `ansible-vault encrypt_string` to create this string.

Install the python cryptography package to speed up decryption: `pip install cryptography`.

## Ansible Configuration File

`ansible.cfg` file in current directory, `~/ansible.cfg` or `/etc/ansible/ansible.cfg` works (with CWD first onwards).

In `[defaults]` section `inventory` sets the inventory file, `vault_password_file` the vault password file, and `roles_path` the path to find roles. 

```
[defaults]
vault_password_file=open_the_vault.sh
inventory = ./inventory
roles_path = ./roles/
```

## YAML

Obviously not specific to Ansible (though see [caveat](#yaml-caveat) below). 

Files start with `---`.

Streams within a file end with `...`. In theory, another can then begin with `---`.

A newline or a space and then `#` until the end of the line are comments (except in literal and folded sections).

`key: value` is a key value mapping. Both key and value can have spaces in the names. Both can be in quotes if desired. Double quotes can have `\"`, `\r`, `\n`, `\0`, `\t`, `\u236A`, `\x0d` etc. Single quotes only have a single escape code available, a double single quote, `''` translates to a single quote.

Numbers can be as is, or use scientific notation like `1e+12`.

Booleans are `true` or `false`.

`null` is the null value, but cal also just leave value blank.

Literal block are started with `|`, are indented, and use blank lines to end paragraphs. Indentation is removed.

```
literal_block: |
  This is the first line.

  This is the second.
```

Folded blocks are the same except that line endings are all kept.

```
folded_block: >
  This is the first line.
  This is the second.
```

Indentation usually uses 2 spaces, and denotes a nested map.

```
a_map:
  key: value
  another_key: another_value
  a_nested_map:
    hello: hello
```

Sequences uses `-` as bullets:

```
- one
- two
- nested_map_key_1: nested_map_value_1
  nested_map_key_2: nested_map_value_2
- - Nested sequence 1 value 1
- - Nested sequence 2 value 1
  - Nested sequence 2 value 2
```

Can use complex keys, like multi-line keys:

```
? |
  This is
  a multi line key
: and this is the value
```

or sequences:

```
? - One
  - Two
: [ 1, 2 ]
```

Can also just include JSON directly, with quotes optional.

### YAML Caveat

Ansible uses `{{ variable_name }}` for variable substitution, but YAML uses `{ }` around maps, so have to quote values that start with `{`. Must quote entire value. Same with anything with a `:` in it.

### Unsafe strings

In Ansible `!unsafe ` can be used as a prefix to a string to prevent it being treated as a Jinja template etc.

## Modules

Module plug-ins (or task or library plug-ins) are bits of code that can be evoked as tasks to do some specific action. 

They should be idempotent.

There are some [common return values](https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html) which may be set by ansible after the task has returned. There are also ones used for internal use that are stripped from the returned structure and have special meaning (`ansible_facts`, `exceptions`, `warnings`, `deprecations`).

## Plug-ins

There are a number of types of plug-ins

* Action plug-ins usually execute before a module to help carry out the action.
* Cache plug-ins cache information. The default is `memory` which just caches during a run.
* Callback plug-ins respond to events, for example to send email with the result of a task.
* Connection plug-ins allow ansible to connect to hosts.
* Inventory plug-ins are used to build the inventory.
* Lookup plug-ins are used to implement [lookups](#lookups), an ansible specific extension to the Jinja2 language.
* Shell plug-ins allow ansible to work with different shells on remote machines.
* Strategy plug-ins control the flow of execution (order of hosts and tasks) in a playbook.
* Vars plug-ins inject variables that didn't come from the inventory, playbook or commend-line.
* Filter plug-ins are used to implement [filters](#filters).
* Test plug-ins are used to implement [tests](#tests).

Plug-ins can be filtered out using a configuration file. [See the documentation for how](https://docs.ansible.com/ansible/latest/user_guide/plugin_filtering_config.html).

## BSD

If using passwords for SSH, it is recomended to change the connection method to `paramiko` because ansible relies on sshpass, which tends to deal badly with BSD password prompts. This can be done globally, or in the inventory.

```
[freebsd]
mybsdhost1 ansible_connection=paramiko
```

To bootstrap, you need python on the target machine. For FreeBSD `ansible -m raw -a "pkg install -y python27" mybsdhost1` usually works. For OpenBSD, `ansible -m raw -a "pkg_add -z python-2.7"` usually does.

You may well need to set the location of the python interpreter

```
[freebsd:vars]
ansible_python_interpreter=/usr/local/bin/python2.7
[openbsd:vars]
ansible_python_interpreter=/usr/local/bin/python2.7
```

Similar for other interpreters for modules not written in python

```
[freebsd:vars]
ansible_python_interpreter=/usr/local/bin/python
ansible_perl_interpreter=/usr/bin/perl5
```
