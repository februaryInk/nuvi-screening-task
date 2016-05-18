# NUVI Interview Project
---

Task: Write a software application that aggregates news data and publishes it to Redis.

This URL (http://bitly.com/nuvi-plz) is an http folder containing a list of zip files. Each zip file contains a bunch of XML files. Each XML file contains 1 news report.

The application needs to download all of the zip files, extract out the XML files, and publish the content of each XML file to a Redis list called “NEWS_XML”.

The application should be idempotent, so that it can be run multiple times without getting duplicate data in the Redis list.
