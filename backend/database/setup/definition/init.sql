/*
 * @file ./database/init.sql
 * @author Adrián Cardona Candil
 * @brief Initializes the database with the specified encoding and locale, loads extensions and creates schemas.
 * @execute psql postgres -f ./database/init.sql
 **/

-- Database definition
create database overture_es
    with encoding = 'UTF8'
    lc_collate = 'es_ES.UTF-8'
    lc_ctype = 'es_ES.UTF-8'
    template = template0;

-- Extensions
\c overture_es
create extension if not exists postgis;
create extension if not exists postgis_topology;
create extension if not exists unaccent;
create extension if not exists pg_trgm;

-- Schemas
create schema if not exists places;
create schema if not exists addresses;
create schema if not exists infrastructures;
create schema if not exists divisions;
create schema if not exists search;