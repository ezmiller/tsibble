library(tidyr)

tsbl <- tsibble(
  qtr = rep(yearquarter("2010 Q1") + 0:9, 3),
  group = rep(c("x", "y", "z"), each = 10),
  value = rnorm(30),
  key = group, index = qtr
)

pedestrian <- pedestrian %>%
  group_by(Sensor) %>%
  slice(1:10) %>%
  ungroup()

tourism <- tourism %>%
  group_by_key() %>%
  slice(1:10) %>%
  ungroup()

test_that("pivot_wider()", {
  out <- tsbl %>%
    pivot_wider(names_from = group, values_from = value)
  expect_s3_class(out, "tbl_ts")
  expect_equal(key(out), list())
  expect_named(out, c("qtr", "x", "y", "z"))
  out_grp <- tsbl %>%
    group_by(group) %>%
    pivot_wider(names_from = group, values_from = value)
  expect_equal(groups(out_grp), list())
  out2 <- tourism %>%
    pivot_wider(names_from = Purpose, values_from = Trips)
  expect_equal(key_vars(out2), c("Region", "State"))
  expect_equal(ncol(out2), 7)
  out3 <- tourism %>%
    pivot_wider(names_from = State, values_from = Trips)
  expect_equal(key_vars(out3), c("Region", "Purpose"))
  expect_equal(ncol(out3), 8 + 3)
  expect_error(tsbl %>% 
    pivot_wider(qtr, names_from = qtr, values_from = value), "can't be widened.")
  out4 <- tourism %>%
    group_by(Purpose) %>%
    pivot_wider(names_from = State, values_from = Trips)
  expect_s3_class(out4, "grouped_ts")
  expect_equal(group_vars(out4), "Purpose")
  out5 <- tourism %>%
    index_by(year = year(Quarter)) %>%
    pivot_wider(names_from = State, values_from = Trips)
  expect_s3_class(out5, "grouped_ts")
  expect_equal(group_vars(out5), "year")
})

tsbl2 <- tsbl %>%
  spread(key = group, value = value)

test_that("pivot_longer()", {
  out <- tsbl2 %>%
    pivot_longer(x:z, names_to = "key", values_to = "value")
  expect_equal(dim(out), c(30, 3))
  expect_equal(key_vars(out), "key")
  out2 <- tsbl2 %>%
    pivot_longer(-qtr, names_to = "key", values_to = "value")
  expect_identical(out, out2)
})

test_that("nest()", {
  expect_s3_class(pedestrian %>% nest(data = -Date_Time), "tbl_ts")
  expect_named(tourism %>% nest(Trips = -Purpose), c("Purpose", "Trips"))
  expect_named(pedestrian %>% nest(data = -Date_Time), c("Date_Time", "data"))
  expect_s3_class(pedestrian %>% nest(data = c(Date, Count)), "tbl_ts")
  expect_named(pedestrian %>% nest(data = dplyr::everything()), "data")
  expect_named(pedestrian %>% nest(data = -Sensor), c("Sensor", "data"))
  expect_named(
    pedestrian %>% group_by(Sensor) %>% nest(),
    names(pedestrian %>% nest(data = -Sensor))
  )
  expect_named(pedestrian %>% nest(ts = -Sensor), c("Sensor", "ts"))
  nested_ped <- pedestrian %>%
    nest(data = -Sensor)
  expect_equal(key_vars(nested_ped$data[[1]]), character(0))
})

nest2_t <- tourism %>%
  group_by_key() %>%
  summarise(
    value = list(quantile(Trips, c(0.3, 0.5, 0.7))),
    qtl = list(c(3, 5, 7))
  )

test_that("unnest_tsibble()", {
  expect_error(nest2_t %>% unnest_tsibble(cols = c(value, qtl)), "A valid tsibble.")
  out <- nest2_t %>%
    unnest_tsibble(cols = c(value, qtl), key = c(key_vars(tourism), qtl))
  expect_s3_class(out, "tbl_ts")
  expect_equal(NCOL(out), 6)
})

harvest <- tsibble(
  year = c(2011, 2013, 2014, 2010, 2012, 2014),
  fruit = rep(c("kiwi", "cherry"), each = 3),
  kilo = sample(1:10, size = 6),
  key = fruit, index = year
)

harvest_fill <- fill_gaps(harvest, .full = TRUE)

test_that("fill()", {
  expect_equal(
    harvest_fill %>%
      group_by_key() %>%
      fill(kilo, .direction = "down"),
    harvest_fill %>%
      as_tibble() %>%
      group_by(fruit) %>%
      fill(kilo, .direction = "down"), ignore_attr = TRUE
  )
  expect_equal(
    harvest_fill %>%
      fill(kilo, .direction = "down"),
    harvest_fill %>%
      as_tibble() %>%
      fill(kilo, .direction = "down"), ignore_attr = TRUE
  )
  expect_s3_class(fill(harvest_fill, kilo), "tbl_ts")
  expect_s3_class(fill(group_by_key(harvest_fill), kilo), "grouped_ts")
})

test_that("drop_na() #173", {
  expect_equal(
    harvest_fill %>%
      group_by_key() %>%
      drop_na(),
    harvest_fill %>%
      as_tibble() %>%
      group_by(fruit) %>%
      drop_na(), ignore_attr = TRUE
  )
  expect_equal(
    harvest_fill %>%
      drop_na(),
    harvest_fill %>%
      as_tibble() %>%
      drop_na(), ignore_attr = TRUE
  )
  expect_s3_class(drop_na(harvest_fill), "tbl_ts")
  expect_s3_class(drop_na(group_by_key(harvest_fill)), "grouped_ts")
})
