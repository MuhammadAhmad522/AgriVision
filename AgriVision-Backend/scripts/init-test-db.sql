-- Create dedicated test database with PostGIS extensions alongside the development database
CREATE DATABASE agrivision_test;
\c agrivision_test
CREATE EXTENSION IF NOT EXISTS postgis;
