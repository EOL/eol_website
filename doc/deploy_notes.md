= MESSAGES TO A FUTURE SELF

== Explanation

...Please include here any information you might want a developer to know, when
they upgrade and deploy the code. Examples include notes about migrations that
are required, scripts that need to be run after the update, suggestions about
features to double-check once they are in production, or even reminders to ping
a specific developer or manager once the code is updated.

Messages that have been acted upon will be removed from this document (they will
persist in git histories, of course).

Thanks.

== THE NOTES:

6/3/2020 (mvitale): db:migrate && bundle required for deploy of changes from branch bye\_refinery (in master)
6/15/2020 (mvitale): Add neo4jrb_url (bolt://...:7687) to secrets.yml. Data download code also metadata migration to have been performed, but will still run if not.
6/18 (jrice): I am upgrading Elasticsearch to 6.8 (from 6.6). This requires a cluster restart.
6/23 (mvitale): autocomplete changes that require Page and TermNode to be reindexed. TermNode can be reindexed in a console using `TermNode.reindex` ...it only takes about 10 minutes.
6/24 (mvitale): For webpacker assets: install Node 10.17.0+ & Yarn 1.x+. bundle install && yarn install. Webpack assets should be automatically compiled in the assets:precompile task; ping me if not.

=== For Deploys After 2020-07-02

* NOTE: I came back to this on Jul 10 to run `MetaMover.run_all` which hadn't been done yet.

7/7/2020 (mvitale): Reindex Page and Term. For production: set config.x.autocomplete\_i18n\_enabled = false in application.rb, then set back to true once reindex is done. rake db:migrate.
7/21/2020 (jrice): Re-check app/models/trait_bank/slurp.rb:86 and make sure it
  includes sample_size citation source remarks method
7/21/20 (mvitale): Forgot to add this earlier -- run TermNameTranslationManager.rebuild\_node\_properties and ObjForPredRelManager.rebuild after latest code is pulled but before restarting webserver. These will make graph changes expected by the trait search typeaheads.

=== For Deploys After 2020-07-27

8/5/2020 (mvitale): Run 'PageStatUpdater.run'
8/7/2020 (mvitale): Ensure unique constraint on Page.page\_id: CREATE CONSTRAINT ON (page:Page) ASSERT page.page\_id IS UNIQUE
10/20/2020 (mvitale): Update translated Term names by running `$ rails r "TermNameTranslationManager.rebuild_node_properties"`

=== For Deploys After 2020-10-21

10/10/2020 (mvitale): Enabled Greek -- run `$ rails r "TermNameTranslationManager.rebuild_node_properties"`
11/4/20 (mvitale): Not a deploy dependency -- can be done after the fact. `$ rails r "PageLandmarkUpdater.run"` to propagate Page native node ranks to Pages in neo4j.

=== For Deploys After 2020-11-06

10/9/2020 (mvitale):
`$ rails r "TermQueryFilterConverter.run" to populate new id fields on existing TermQueryFilters.
`$ bundle install` to install updated neo4jrb gems (now activegraph and neo4j-ruby-driver). Install seabolt per https://github.com/neo4jrb/neo4j-ruby-driver.
Add neo4j_driver_url, neo4j_user, neo4j_password to secrets.yml (see sample)
`$ bundle update eol\_terms && rails r "TermBootstrapper.new.load"` to convert string eol\_ids to integers.

2020-12-09 (jrice):
`rails r "TraitBank::Admin.create_constraints"`
`rails r "TermBootstrapper.new.load"` to fix String eol_ids
`rails r "Locale.rebuild\_language\_mappings"`
`rails r "OrderedFallbackLocale.rebuild"`

2020-12-15 (mvitale):
`rails r "TermNode.reindex"`

=== For Deploys after 2021-4-26

run Locale.rebuild_language_mappings after the deploy
