# Database Evolution Framework

> In a service oriented architecture, dealing with the evolution of the underlying database is not a trivial problem.
> New functional requirements are often associated with modifications of the domain model, hence with modifications of the relational schema.
> These modifications have to be done in a way that does not impact existing services and applications.
> They also have to be done in a way that preserves consistency in the data store.
> Last but not least, they have to be done in a way that has minimal impact on the service availability.
> In this paper, we propose a framework that supports the development, maintenance and operational activities.
> The framework consists of processes, tools and best practices.
> It is the result of our practical experience with a large-scale commercial internet service, which is characterized both by a constant and rapid functional evolution and by strict operational constraints.

* [Paper](doc/tex/pa.pdf)

## Ruby Migration Tool

This Subversion-based command line tool can download individual migration scripts (for separate features or parts of a feature) from a repository and assemble them into a standalone database migration script for a project release.

```bash
git clone git@github.com:lotaris/migrator.git
cd migrator/src
bundle install
./src/migrator.rb --help
```

## License

The **migrator command line tool** is licensed under the [MIT License](http://opensource.org/licenses/MIT).
See [LICENSE.txt](src/LICENSE.txt) for the full text.
