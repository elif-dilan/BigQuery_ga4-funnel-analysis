--select * FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

SELECT
  TIMESTAMP_MICROS(event_timestamp) as event_timestamp,
  user_pseudo_id,

  (
    select value.int_value
    from unnest(event_params)
    where key='ga_session_id'
  ) as session_id,

  event_name, 
  geo.country as country,
  device.category as device_category,

  traffic_source.source as source,
  traffic_source.medium as medium,
  traffic_source.name as campaign

from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
where _TABLE_SUFFIX between '20210101' and '20211231'
and event_name IN(
  'session_start',
  'view_item',
  'add_to_cart',
  'begin_checkout',
  'add_shipping_info',
  'add_payment_info',
  'purchase'
);
------------------------------------------------------------------------


WITH base AS (
  SELECT
    DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS session_id,

    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign,

    event_name

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20211231'

  and event_name IN (
     'session_start',
    'add_to_cart',
    'begin_checkout',
    'purchase'
  )
),

session_level AS (
  SELECT
    event_date,
    source,
    medium,
    campaign,

    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS unique_session,

    MAX(CASE WHEN event_name = 'session_start' THEN 1 ELSE 0 END) AS has_session,
    MAX(CASE WHEN event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS has_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS has_checkout,
    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS has_purchase

  FROM base
  GROUP BY event_date, source, medium, campaign, unique_session
)

SELECT
  event_date,
  source,
  medium,
  campaign,

  COUNT(DISTINCT unique_session) AS user_sessions_count,

  ROUND(SUM(has_cart) * 100.0 / COUNT(DISTINCT unique_session), 2) AS visit_to_cart,
  ROUND(SUM(has_checkout) * 100.0 / COUNT(DISTINCT unique_session), 2) AS visit_to_checkout,
  ROUND(SUM(has_purchase) * 100.0 / COUNT(DISTINCT unique_session), 2) AS visit_to_purchase

FROM session_level


WHERE has_session = 1

GROUP BY event_date, source, medium, campaign
ORDER BY event_date;

------------------------------------------------------------------------


with base as (
  select
    user_pseudo_id,
    (
      select value.int_value
      from unnest(event_params)
      where key='ga_session_id'
    ) as session_id,

    event_name,

    (
      select value.string_value
      from unnest(event_params)
      where key='page_location'
    ) as page_location

  from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  where _TABLE_SUFFIX BETWEEN '20200101' AND '20201231'
),

landing_pages AS (
  select
    concat(user_pseudo_id, '-', cast(session_id as string)) as unique_session,
    regexp_extract(page_location, r'https?://[^/]+(/[^?]*)') AS page_path
  from base
  where event_name= 'session_start'
),

purchases as(
  select distinct
    concat(user_pseudo_id, '-', cast(session_id as string)) as unique_session
  from base
  where event_name='purchase'
)

select
  lp.page_path,
  
  count(DISTINCT lp.unique_session) as unique_session,
  count(DISTINCT p.unique_session) as purchase,

  round(
    count(DISTINCT p.unique_session)*100.0/
    count(DISTINCT lp.unique_session),
    2
  ) as purchase_conv
from landing_pages lp
left join purchases p
  on lp.unique_session=p.unique_session

  group by lp.page_path
  order by purchase_conv desc
;

------------------------------------------------------------------------------


WITH session_data AS (
  SELECT
    CONCAT(user_pseudo_id, '-', CAST((
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS STRING)) AS unique_session,

    MAX(CASE 
      WHEN (
        SELECT value.string_value
        FROM UNNEST(event_params)
        WHERE key = 'session_engaged'
      ) = '1' THEN 1
      ELSE 0
    END) AS session_engaged,

    SUM(COALESCE((
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'engagement_time_msec'
    ),0)) AS engagement_time,

    MAX(CASE WHEN event_name = 'purchase' THEN 1 ELSE 0 END) AS purchase_flag

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20211231'
  GROUP BY unique_session
)

SELECT
  CORR(session_engaged, purchase_flag) AS engaged_purchase_corr,
  CORR(engagement_time, purchase_flag) AS time_purchase_corr
FROM session_data;





