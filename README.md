# Knife Mirror plugin

This plugin adds additional functionality to the Chef Knife command line tool for mirroring Chef Supermarket content (community &amp; private, cookbooks, tools etc)

Still WIP, use at your own risk of course :-)

This started out as some simple poc code, as an extra extension/command to knife-supermarket (knife supermarket mirror).
While that still makes sense, I went for this specific 'knife-mirror' Gem for now.

oh, and, this is my first ever Gem, I don't have a clue what I'm doing...

## Currently it does the following

- mirror single cookbook version(s)
- mirror single cookbook, all versions
- mirror all cookbooks, all versions
- skip on (most) errors
- specify source and target Supermarkets
- save failed cookbook versions
- configurable delay to ease load on Supermarkets
- process cookbook direct dependencies as well

Most is based on working with diffs between source and target so we do not waste too many resources.

## Some notes (ok, a lot)

Please Note: currently, ownership for uploaded cookbooks is set to you, the knife user/client.

Another Note: the community supermarket contains cookbooks, specifically older/early versions, which do not process correctly in newer/recent (private) supermarkets.
Not much I can do about that. Most failures have to do with improper platform arrays in metadata.
Mirroring will simply skip these faulty versions.

k, one more Note: please understand we pass cookbook tarballs unaltered! Do not blame this mirror tool for not being able to process some cookbook version(s).

Again: we do not unpack any downloaded cookbooks locally, this mirroring works differently from the usual download and share process.

Last Note: Had code in place for replicating 'category' and other meta data, however, that causes mirroring to skip a lot of cookbooks since by default:

```
supermarket=# SELECT * FROM categories;
 id | name  |         created_at         |         updated_at         | slug
----+-------+----------------------------+----------------------------+-------
  1 | Other | 2015-09-07 15:40:29.854929 | 2015-09-07 15:40:29.854929 | other
(1 row)
```

If the requested catagory does not exist, supermarket refuses to accept the cookbook :(

So obviously need to revisit that.

## Requirements

- You need to have Chef Knife working
- You need an account on the target supermarket of course
- This Gem, dohh

You do not need an account on the source/community supermarket.

## Install

```
gem install knife-mirror
```

or obtain this source (git clone or whatever) and

```
gem build knife-mirror.gemspec; gem install knife-mirror-0.1.2.gem
```

## Use

For using knife you obviously need a matching key pair.
You have the private key on your workstation while the pub key is stored on chef server.
By using oauth2, Supermarket will know your pub key as well, allowing for knife to work with Supermarket as well.
So, at least sign in once, after which you should be able to knife to the Supermarket.

Then things are really simple, while we still work on more advanced stuff:

### Only most recent version for a specific cookbook

```
knife mirror apt -t https://supermarket.your.domain.tld
```

### Only most recent version for a specific cookbook, plus its dependencies

```
knife mirror apt -t https://supermarket.your.domain.tld --deps
```

### Specific cookbook version

```
knife mirror apt 1.2.3 -t https://supermarket.your.domain.tld
```

### Specific cookbook, all versions

```
knife mirror apt all -t https://supermarket.your.domain.tld
```

### All cookbooks

```
knife mirror all -t https://supermarket.your.domain.tld
```

### All cookbooks, delay 30 secs, keep failed cookbook versions

```
knife mirror all -t https://supermarket.your.domain.tld --delay 30 --keep
```

### All cookbooks, from one private supermarket to some other private supermarket, keep failed cookbooks in a subdir 'temp'

```
knife mirror all -m https://supermarketA.your.domain.tld -t https://supermarketB.your.domain.tld --keep -d temp
```

Obviously the ```--delay``` only makes sense for multiple versions and/or multiple cookbooks.

The ```--keep``` will save a tarball: cookbook-version.tar.gz

The ```--keep -d temp``` will save tarballs to: temp/cookbook-version.tar.gz (please ensure 'temp' exists)

## Todo

Wow, still lots to do, lots of wishes :(

- proper replication of deprecation flag (not honored as part of the cookbook meta upload)
- proper replication of urls (same reason)
- replicate (and create) categories?
- process replacement in case we're mirroring a deprecated cookbook
- some automated testing
- more/better docs?
- find/work a way to replicate/correct/assign ownership

That last item still needs some further research, though I have some very good clues to work out and try.

The other items are fairly trivial though I find it a bit frustrating the Supermarket code won't simply honor extra meta data. Currently it only handles 'category'.
Maybe I'll create a patch against Supermarket and submit a PR, though I'll first run that by Chef to find out if that would make sense.
Until that time though, things require some extra calls :(

## Rubocop and friends

Yes, rubocop still likes complaining about some complexity and linelength. So sue me...

Pulling things apart into sep methods and such won't make things more efficient. But I'll look into it some time ;-)

For now I was more concerned with making it work and putting it out there. I'm convinced things can be refactored, yes.

## CONTRIBUTING

Please file bugs against this project at [Knife mirror issues](https://github.com/gjmoed/knife-mirror/issues).

## LICENSE

```
Author:: G.J. Moed (<gmoed@kobo.com>)
Copyright:: Copyright (c) 2015 Rakuten Kobo Inc.
License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
