
# needed libraries not on CRAN
# remotes::install_github("dill/emoGG")
# remotes::install_github("CorrelAid/datenguideR")

# load libraries
pacman::p_load(
  datenguideR,
  emoGG,
  gganimate,
  ggthemes,
  gifski,
  magick,
  tidyverse
)

# data containing population by region
(df_population <-
  datenguideR::dg_call(
    nuts_nr = 1,
    stat_name = "BEV028",
    year = c(
      2006,
      2007,
      2008,
      2009,
      2010,
      2011,
      2012,
      2013,
      2014,
      2015,
      2016,
      2017,
      2018
    )
  ) %>%
  dplyr::select(id, year, population = value)
)

# data containing trash output by region
(df_trash <-
  datenguideR::dg_call(
    nuts_nr = 1,
    stat_name = "AEW010",
    year = c(
      2006,
      2007,
      2008,
      2009,
      2010,
      2011,
      2012,
      2013,
      2014,
      2015,
      2016,
      2017,
      2018
    )
  ) %>%
  dplyr::select(
    trash = value,
    dplyr::everything(),
    -name
  )
)


# writing the data file
# (just because the API is not stable and sometimes returns NAs)
# readr::write_csv(df, "datenguideR.csv")

# extracting id names for each region
df_combined <- df_trash %>%
  dplyr::left_join(
    x = .,
    y = df_population, by = c("id", "year")
  ) %>%
  dplyr::left_join(
    x = .,
    y = datenguideR::dg_regions %>%
      dplyr::filter(level == "nuts1") %>%
      dplyr::select(id, name),
    by = "id"
  )

# creating means by name and year
df_combined %<>%
  dplyr::group_by(name, year) %>%
  dplyr::summarise(mean_trash = mean(trash, na.rm = TRUE), population = population) %>%
  dplyr::ungroup() %>%
  mutate(
    mean_trash_std_ton = mean_trash / population,
    mean_trash_std_kg = mean_trash_std_ton * 1000
  )

# adding cumulative sum
df_combined %<>%
  dplyr::group_by(name) %>%
  dplyr::mutate(cumsum = cumsum(mean_trash_std_kg)) %>%
  dplyr::ungroup()

# adding cumsum17
cumsum17 <- df_combined %>%
  dplyr::filter(year == 2017) %>%
  dplyr::group_by(name) %>%
  dplyr::mutate(cumsum17 = cumsum(cumsum)) %>%
  dplyr::ungroup() %>%
  dplyr::select(name, cumsum17)


# library(png)
# img <- readPNG(system.file("img", "Rlogo.png", package="png"))
# pic1 <- readPNG("clipart/truck.png")
#
# df_truck <- tibble(name = c(1:16),
#                        truck = list(pic1))


df_combined %<>%
  dplyr::left_join(cumsum17, by = "name")


# Label
dg_descriptions %>%
  dplyr::filter(stat_name == "AEW010") %>%
  dplyr::select(stat_description_full)


# Plot V1
# make plot
p_rainbow <- df_combined %>%
  dplyr::mutate(name = forcats::fct_reorder(name, cumsum17)) %>%
  ggplot(aes(x = name, y = cumsum)) +
  geom_col(width = 0.05) +
  geom_point(aes(color = name), size = 6) +
  coord_flip() +
  ggthemes::theme_tufte() +
  theme(legend.position = "none", text = element_text(size = 20)) +
  guides(legend = FALSE) +
  labs(
    title = "How much trash does Germany accumulate over time? 
      \n (Since 2006 to {frame_time})",
    y = "cumulative amount of waste discharged (in kilogram per capita)",
    x = "",
    caption = "Source: GENESIS-Statistik 'Erhebung der Abfallentsorgung' (32111)"
  ) +
  scale_y_continuous(label = scales::label_number_si(unit = "kg")) +
  transition_time(year) +
  ease_aes("linear")

# creating a fancy animated visualization
gganimate::animate(
  plot = p_rainbow,
  renderer = gganimate::gifski_renderer(loop = F),
  duration = 10,
  width = 900,
  height = 600,
  end_pause = 50
)

gganimate::anim_save(
  filename = "trash_rainbow.gif",
  animation = last_animation()
)

## plot V2
# make plot
p_emoji <- df_combined %>%
  mutate(name = fct_reorder(name, cumsum17)) %>%
  ggplot(aes(x = name, y = cumsum)) +
  geom_col(width = 0.1) +
  emoGG::geom_emoji(emoji = "1f34c") +
  coord_flip() +
  ggthemes::theme_tufte() +
  theme(
    legend.position = "none",
    text = element_text(size = 20)
  ) +
  guides(legend = FALSE) +
  labs(
    title = "How much trash does Germany accumulate over time? 
      \n (Since 2006 to {frame_time})",
    y = "cumulative amount of waste discharged (in kilogram per capita)",
    x = "",
    caption = "Source: GENESIS-Statistik 'Erhebung der Abfallentsorgung' (32111)"
  ) +
  scale_y_continuous(label = scales::label_number_si(unit = "kg")) +
  transition_time(year) +
  ease_aes("linear")


# creating a fancy animated visualization
p <- gganimate::animate(
  plot = p_emoji,
  renderer = gganimate::gifski_renderer(loop = F),
  duration = 10,
  width = 900,
  height = 600,
  end_pause = 50
)

gganimate::anim_save(
  filename = "trash_emoji.gif",
  animation = p
)


# save
rio::export(df_combined, "data/waste.csv")
rio::export(dg_descriptions, "data/datenguide_description.csv")

# Sources:
#
# - incorporate emojies: https://github.com/dill/emoGG
# - animated plot: https://gganimate.com/
# - data: https://www.regionalstatistik.de/genesis/online/data;sid=1B9D622CFEA587BAE92DE292DC3AE1A8.reg2?operation=statistikLangtext&levelindex=0&levelid=1575195102089&index=1
# - https://www.destatis.de/DE/Methoden/Qualitaet/Qualitaetsberichte/Umwelt/abfallentsorgung.pdf?__blob=publicationFile&v=4
