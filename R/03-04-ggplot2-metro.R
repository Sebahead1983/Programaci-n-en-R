library(tidyverse)
library(scales)
library(corrr)
library(patchwork)
library(widyr)
library(igraph)
library(ggnetwork)
library(ggforce)
library(chilemapas)

theme_set(
  theme_get() +
    theme(legend.position = "bottom")
)

# sobresicribir los parámetros por default
# lo hago pues no me gusta el color tan claro
# _amarillo chillón_ en la escala viridis.
scale_fill_viridis_d  <- partial(
  ggplot2::scale_fill_viridis_d ,
  begin = 0.05, end = 0.9
)
scale_color_viridis_d <- partial(
  ggplot2::scale_color_viridis_d,
  begin = 0.05, end = 0.9
)



ruta_datos <- here::here("posts/2023-07-09-visualizacion-en-el-analisis-de-datos/data")

data <- data.table::fread(fs::path(ruta_datos, "2015.04_Subidas_paradero_mediahora_web.csv.gz"))
data <- as_tibble(data)

data



data <- data |>
  filter(!str_detect(paraderosubida, "[0-9]+-[0-9]")) |>
  filter(paraderosubida != "-")



data <- data |>
  mutate(mediahora = readr::parse_guess(mediahora)) |>
  filter(hour(mediahora) > 0)



data <- complete(
  data,
  paraderosubida,
  mediahora,
  fill = list(subidas_laboral_promedio = 0)
)

data



dplazamaipu <- data |>
  filter(paraderosubida == "PLAZA MAIPU")

p0 <- ggplot(dplazamaipu) +
  geom_point(aes(subidas_laboral_promedio, mediahora, color = paraderosubida), size = 1.5) +
  scale_x_continuous(labels = comma) +
  scale_color_viridis_d(guide = "none")

p0



ggplot(dplazamaipu) +
  geom_path(aes(subidas_laboral_promedio, mediahora, color = paraderosubida), size = 1.5) +
  scale_x_continuous(labels = comma) +
  scale_color_viridis_d(guide = "none")



ggplot(dplazamaipu) +
  geom_path(aes(mediahora, subidas_laboral_promedio, color = paraderosubida), size = 1.5) +
  scale_y_continuous(labels = comma) +
  scale_color_viridis_d(name = NULL)



d1 <- data |>
  filter(paraderosubida %in% c("PLAZA MAIPU", "LAGUNA SUR"))

c <- d1 |>
  pivot_wider(
    names_from = paraderosubida,
    values_from = subidas_laboral_promedio
  ) |>
  corrr::correlate(quiet = TRUE) |>
  select(2) |>
  pull() |>
  na.omit() |>
  as.numeric()

p1 <- ggplot(d1) +
  geom_line(
    aes(mediahora, subidas_laboral_promedio,
        color = paraderosubida,
        group = paraderosubida),
    size = 1.2
  ) +
  scale_y_continuous(label = scales::comma) +
  scale_color_viridis_d()

p1



set.seed(123)

n <- 100
x <- rnorm(n)
e <- rnorm(n)

pc <- tibble(
  beta  = c(0,  1, 1, -1, -1, 0),
  beta2 = c(0,  0, 0,  1,  0, 1),
  sd    = c(1,  1, 0,  0,  1, 1),
) |>
  pmap_df(function(beta = 1, beta2 = 1, sd = 1){
    tibble(
      x = x,
      y = beta * x + beta2 * x^2 + sqrt(sd) * e,
      cor = cor(x, y)
    )
  }) |>
  mutate(
    cor = round(cor, 3),
    cor = str_glue("{cor} ({ percent(cor)})"),
    cor = fct_inorder(as.character(cor))
  ) |>
  ggplot(aes(x, y)) +
  geom_point(alpha = 0.25) +
  geom_smooth(method = "lm", color = "darkred", size = 1.2,
              formula = y ~  x, se = FALSE) +
  facet_wrap(vars(cor), scales = "free") +
  theme(
    axis.text.x = element_text(size = 6),
    axis.text.y = element_text(size = 6),
  )

pc



lab_dates <- d1 |>
  spread(paraderosubida, subidas_laboral_promedio)  |>
  pull(mediahora) |>
  as_datetime() |>
  pretty(6)

lab_dates_lbls <- str_extract(lab_dates, "[0-9]{2}:[0-9]{2}")

p2 <- d1 |>
  spread(paraderosubida, subidas_laboral_promedio) |>
  mutate(mediahora = as_datetime(mediahora)) |>
  ggplot(aes(`LAGUNA SUR`, `PLAZA MAIPU`)) +
  geom_point(aes(color = as.numeric(mediahora)), size = 3) +
  scale_y_continuous(label = scales::comma) +
  scale_x_continuous(label = scales::comma) +
  scale_color_viridis_c(name = NULL, breaks = as.numeric(lab_dates), labels = lab_dates_lbls) +
  labs(subtitle = str_glue("Correlación { percent(c, , accuracy = 0.01) }"))


p1 | p2



d1 <- data |>
  filter(paraderosubida %in% c("UNIVERSIDAD DE CHILE", "PLAZA DE PUENTE ALTO"))

c <- d1 |>
  pivot_wider(
    names_from = paraderosubida,
    values_from = subidas_laboral_promedio
  ) |>
  corrr::correlate(quiet = TRUE) |>
  select(2) |>
  pull() |>
  na.omit() |>
  as.numeric()

p1 <- ggplot(d1) +
  geom_line(
    aes(mediahora, subidas_laboral_promedio, color = paraderosubida, group = paraderosubida),
    size = 1.2
  ) +
  scale_y_continuous(label = scales::comma) +
  scale_color_viridis_d(name = NULL)

p2 <- d1 |>
  spread(paraderosubida, subidas_laboral_promedio) |>
  mutate(mediahora = as_datetime(mediahora)) |>
  ggplot(aes(`PLAZA DE PUENTE ALTO`, `UNIVERSIDAD DE CHILE`)) +
  geom_point(aes(color = as.numeric(mediahora)), size = 3) +
  scale_y_continuous(label = scales::comma) +
  scale_x_continuous(label = scales::comma) +
  scale_color_viridis_c(name = NULL, breaks = as.numeric(lab_dates), labels = lab_dates_lbls) +
  labs(subtitle = str_glue("Correlación { percent(c, , accuracy = 0.01) }"))

p1 | p2



dcor <- data |>
  widyr::pairwise_cor(
    paraderosubida,
    mediahora,
    subidas_laboral_promedio
  )

ncors <- dcor |>
  nrow() |>
  comma()

nest <- dcor |>
  count(item1) |>
  nrow() |>
  comma()



ggplot(dcor) +
  geom_tile(aes(item1, item2, fill = correlation)) +
  scale_fill_viridis_c(limits = c(-1, 1), breaks = seq(-1, 1, length.out = 5), labels = percent) +
  theme(
    axis.text.y = element_text(size = 3),
    axis.text.x = element_text(size = 3, angle = 90, hjust = 1),
    legend.position = "right",
    legend.key.width = unit(0.5, "cm")
  ) +
  labs(x = NULL, y = NULL)



M <- data |>
  spread(paraderosubida, subidas_laboral_promedio) |>
  select(-1) |>
  mutate_all(replace_na, 0) |>
  cor()

order <- corrplot::corrMatOrder(M, order = "hclust")

M <- M[order, order]

lvls <- colnames(M)

dcor <- dcor |>
  mutate(across(where(is.character), ~ factor(.x,  levels = lvls)))

pcors <- ggplot(dcor) +
  geom_tile(aes(item1, item2, fill = correlation)) +
  scale_fill_viridis_c(limits = c(-1, 1), breaks = seq(-1, 1, length.out = 5), labels = percent) +
  theme(
    axis.text.y = element_text(size = 3),
    axis.text.x = element_text(size = 3, angle = 90, hjust = 1),
    legend.position = "right",
    legend.key.width = unit(0.5, "cm")
  ) +
  labs(x = NULL, y = NULL) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )

pcors



ncors <- 250

dcorf <- dcor |>
  filter(as.character(item1) < as.character(item2)) |>
  arrange(desc(correlation)) |>
  mutate(w = correlation*correlation) |>
  head(ncors)



g <- graph_from_data_frame(dcorf, directed = FALSE)

E(g)$weight <- dcorf$w

wc <- cluster_fast_greedy(g)
nc <- length(unique(membership(wc)))

dvert <- tibble(paraderosubida = V(g)$name) |>
  mutate(comm = as.numeric(membership(wc))) |>
  left_join(
    data |>
      group_by(paraderosubida) |>
      summarise(n = sum(subidas_laboral_promedio)),
    by = "paraderosubida"
  ) |>
  left_join(
    data |>
      group_by(paraderosubida) |>
      summarise(tend = cor(seq(1, n()), subidas_laboral_promedio)),
    by = "paraderosubida"
  ) |>
  ungroup()

# dvert
V(g)$label <- dvert$paraderosubida
V(g)$size <- dvert$n
V(g)$subidas_totales_miles <- round(dvert$n/1000, 2)
V(g)$comm <- as.numeric(membership(wc))
V(g)$tendencia <- round(dvert$tend, 2)
V(g)$color <- dvert$comm

set.seed(123)

dfnet <- ggnetwork(g)

dfnet2 <- dfnet |>
  as.matrix() |>
  as.data.frame() |>
  as_tibble() |>
  select(x, y, name, weight, size, color) |>
  mutate_all(as.character) |>
  mutate_at(vars(x, y, weight, size), as.numeric) |>
  filter(is.na(weight))

pnet <- ggplot(dfnet) +
  geom_edges(
    aes(-x, -y, size = width, color = factor(comm), xend = -xend, yend = -yend),
    color = "gray50", size = 1, alpha = 0.25
  ) +
  geom_point(
    aes(-x, -y, size = size, color = factor(comm), fill = factor(comm)), shape = 21
  ) +
  ggrepel::geom_text_repel(
    aes(-x, -y, label = name), size = 2,
    data = dfnet2, color = "#666666",
    force = 10,
    family = "main_font"
  ) +
  scale_fill_viridis_d(name = "Comunidad") +
  # scale_color_viridis_d() +
  scale_size(guide = "none") +
  theme(
    panel.grid.major = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    legend.position = "right"
  ) +

  guides(
    color = guide_legend(override.aes = list(size = 5)),
    fill = guide_legend(override.aes = list(size = 5))
  ) +

  labs(
    x = NULL,
    y = NULL,
    size = "Subidas",
    color = "Comunidad"
  ) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )

pnet



nhead <- 8

datas <- data |>
  mutate(mediahora = format(mediahora, "%R")) |>
  spread(mediahora, subidas_laboral_promedio)

datas <- datas |>
  mutate_if(is.numeric, replace_na, 0)

datas |>
  select(1:8) |>
  head(nhead)



library(uwot)

set.seed(123)

um <- umap(datas, verbose = TRUE, n_threads = 3, n_neighbors = 20)

dumap <- as.data.frame(um) |>
  as_tibble() |>
  mutate(paraderosubida = pull(datas, paraderosubida)) |>
  select(paraderosubida, everything())

dumap



set.seed(1234)

pumap <- ggplot(dumap) +
  geom_point(aes(V1, V2), alpha = 0.3) +
  ggrepel::geom_text_repel(
    aes(V1, V2, label = paraderosubida),
    data = dumap |> sample_n(30),
    size = 3,
    force = 10
  )

pumap



withins <- map_dbl(1:15, function(k = 4){
  km <- kmeans(
    dumap |> select(-paraderosubida),
    centers = k,
    nstart = 50,
    iter.max = 150
  )
  km$tot.withinss
})

# plot(withins)
km <- kmeans(
  dumap |> select(-paraderosubida),
  centers = 4,
  nstart = 50,
  iter.max = 150
)

dumap <- dumap |>
  mutate(cluster = as.character(km$cluster))

dcenters <- km$centers |>
  as.data.frame() |>
  as_tibble() |>
  mutate(cluster = as.character(row_number()))

# xmin, xmax, ymin, ymax.
bnd <- c(-4, 4, -4, 4)

set.seed(1234)

pumapkm <- ggplot(dumap, aes(V1, V2, fill = cluster, group = -1)) +
  geom_voronoi_tile(data = dcenters, alpha = 0.2, bound = bnd) +
  geom_voronoi_segment(data = dcenters, color = "gray70", bound = bnd) +
  geom_point(aes(V1, V2, fill = cluster), alpha = 0.3) +
  ggrepel::geom_text_repel(
    aes(V1, V2, label = paraderosubida),
    data = dumap |> sample_n(30),
    size = 3,
    force = 10
  ) +
  scale_fill_viridis_d() +
  xlim(c(-4, 4)) + ylim(c(-4, 4)) +
  theme(legend.position = "none")

pumapkm



dkm <- tibble(
  tot.withinss = withins,
  cluster      = seq(length(withins))
)

pkm <- ggplot(dkm, aes(cluster, tot.withinss, fill = "1", color = "1")) +

  geom_line(size = 2) +
  geom_point(size = 3, shape = 21, color = "white") +
  scale_x_continuous(breaks = dkm$cluster) +
  labs(
    y = "Suma de los cuadrados dentro de cada grupo",
    x = "Grupos"
  ) +
  scale_fill_viridis_d() +
  scale_color_viridis_d() +
  theme(legend.position = "none")

pkm



library(ggdendro)

dhclust <- dumap |>
  column_to_rownames("paraderosubida") |>
  select(V1, V2)

hc       <- hclust(dist(dhclust), "ave")           # heirarchal clustering
dendr    <- dendro_data(hc, type="rectangle")    # convert for ggplot
clust    <- cutree(hc, k = 4)                    # find 4 clusters
clust.df <- data.frame(label = names(clust), cluster = factor(clust))
dendr[["labels"]] <- merge(dendr[["labels"]], clust.df, by = "label")

pdend <- ggplot() +
  geom_segment(
    data = segment(dendr),
    aes(x = x, y = y, xend = xend, yend = yend)
  ) +
  geom_text(
    data = label(dendr),
    aes(x, y, label = label, hjust = 1, color = cluster),
    size = 1.8

  ) +
  coord_flip() +
  scale_color_viridis_d() +
  # scale_y_continuous(limits = c(-0.10, NA)) +
  # scale_y_reverse(expand=c(0.2, 0)) +
  theme(
    axis.line.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.y = element_blank(),
    axis.title.y = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid = element_blank(),
    legend.position = "right"
  ) +
  guides(color = guide_legend(override.aes = list(size = 5)))

pdend



library(ape)

plot(
  ape::as.phylo(hc),
  type = "unrooted",
  edge.width = 2,
  edge.lty = 2,
  # tip.color = colors[clust],
  no.margin = TRUE,
  label.offset = 0.5,
  plot = FALSE
)

L <- get("last_plot.phylo", envir = .PlotPhyloEnv)

dedges <- tibble(x = L$xx, y = L$yy) |>
  mutate(id = row_number())

dedges2 <- as.data.frame(L$edge) |>
  as_tibble() |>
  left_join(dedges, by = c("V1" = "id")) |>
  left_join(dedges, by = c("V2" = "id"),  suffix = c("", "_end"))

dnodes <- dedges |>
  head(length(clust)) |>
  mutate(
    paraderosubida = names(clust),
    cluster = as.character(clust)
  )



pphylo <- ggplot(dedges2) +
  geom_segment(
    aes(x = x, y = y, xend = x_end, yend = y_end, group = -1L),
    color = "gray70",
    size = .9
  ) +
  ggrepel::geom_text_repel(
    aes(x, y, label = paraderosubida),
    data = dnodes,
    size = 1.5,
    max.overlaps = 1000,
    segment.colour = "gray80"
  )  +
  geom_point(
    aes(x, y, fill = cluster),
    data = dnodes,
    shape = 21, color = "white", size = 4
  ) +
  scale_color_viridis_d()  +
  scale_fill_viridis_d()  +
  theme(
    panel.grid.major = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    legend.position = "right"
  ) +
  labs(x = NULL, y = NULL) +
  scale_y_continuous(expand = expansion(mult = 0.25)) +
  scale_x_continuous(expand = expansion(mult = 0.25))

pphylo



dataf <- data |>
  left_join(dumap |> select(paraderosubida, cluster), by = "paraderosubida")

pclus <- ggplot(dataf, aes(mediahora, subidas_laboral_promedio)) +
  geom_line(aes(group = paraderosubida), alpha = 0.8, size = 0.8, color = "gray90") +
  geom_smooth(
    aes(color = cluster),
    se = FALSE, size = 2,
    method = 'gam',
    formula = y ~ s(x, bs = "cs")
  ) +
  scale_color_viridis_d() +
  facet_wrap(vars(cluster)) +
  scale_y_continuous(labels = comma)

pclus



routes <- read_csv(fs::path(ruta_datos, "routes.txt"))
trips  <- read_csv(fs::path(ruta_datos, "trips.txt"))
stops  <- read_csv(fs::path(ruta_datos, "stops.txt"),
                   col_types = cols(stop_url = col_character()))

shapes <- data.table::fread(fs::path(ruta_datos, "shapes.csv.gz"))
shapes <- as_tibble(shapes)

stops_metro <- stops |>
  filter(!grepl("\\d", stop_id)) |>
  mutate(stop_url = basename(stop_url))

routes_metro <- routes |>
  filter(grepl("^L\\d",route_id))

shapes_metro <- routes |>
  filter(grepl("^L\\d",route_id)) %>%
  semi_join(trips, .,  by = "route_id") %>%
  semi_join(shapes, ., by = "shape_id") |>
  ### IMPORTANTE
  filter(str_detect(shape_id, "-I")) |>
  mutate(shape_id2 = str_replace(shape_id, "-I", ""))

colors_metro <- distinct(shapes, shape_id) |>
  left_join(distinct(trips, shape_id, route_id), by = "shape_id") |>
  left_join(distinct(routes, route_id, route_color), by = "route_id") |>
  semi_join(shapes_metro, by = "shape_id") |>
  mutate(route_color = paste0("#", route_color))

str_to_id2 <- function(x) {
  x |>
    as.character() |>
    str_trim() |>
    str_to_lower() |>
    str_replace_all("\\\\s+", "_") |>
    str_replace_all("\\\\\\\\|/", "_") |>
    str_replace_all("\\\\[|\\\\]", "_") |>
    str_replace_all("_+", "_") |>
    str_replace_all("_$|^_", "") |>
    str_replace_all("á", "a") |>
    str_replace_all("é", "e") |>
    str_replace_all("í", "i") |>
    str_replace_all("ó", "o") |>
    str_replace_all("ú", "u") |>
    str_replace_all("ñ", "n") |>
    str_replace_all("`", "") |>
    str_replace_all("_de_", "_")
}

dumap <- mutate(dumap, id = str_to_id2(paraderosubida))

data4 <- dataf |>
  group_by(paraderosubida, cluster) |>
  summarise(median = median(subidas_laboral_promedio), .groups = "drop") |>
  ungroup() |>
  mutate(id = str_to_id2(paraderosubida))

stops_metro_data <- stops_metro |>
  mutate(id = str_to_id2(stop_name)) |>
  left_join(data4, by = "id") |>
  filter(!is.na(cluster))

rm(shapes, routes, stops, trips, data4)

colors_metro_manual <- colors_metro |>
  select(name = route_id, value = route_color) |>
  deframe()

pmetro <- ggplot() +
  geom_path(
    data = shapes_metro,
    aes(shape_pt_lon, shape_pt_lat, color = shape_id2),
    size = 2
  ) +
  geom_point(
    data = stops_metro_data,
    aes(stop_lon, stop_lat, size = log(median), fill = cluster),
    shape = 21, color = "white"
  ) +
  scale_color_manual(name = "Línea", values = colors_metro_manual) +
  scale_size(guide = "none") +
  scale_fill_viridis_d(name = "Clúster") +
  coord_equal() +
  guides(
    color = guide_legend(override.aes = list(size = 5)),
    fill = guide_legend(override.aes = list(size = 5))
  ) +
  theme(
    panel.grid.major = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    legend.position = "right"
  )  +
  facet_wrap(vars(cluster))

pmetro



pmetro2 <- ggplot() +
  geom_sf(
    data = chilemapas::mapa_zonas |> filter(codigo_region == "13"),
    aes(geometry = geometry),
    alpha = 0.5,
    color = "white"
  ) +
  geom_path(
    data = shapes_metro,
    aes(shape_pt_lon, shape_pt_lat, color = shape_id2),
    size = 2
  ) +
  geom_point(
    data = stops_metro_data,
    aes(stop_lon, stop_lat, size = log(median), fill = cluster),
    shape = 21, color = "white"
  ) +
  scale_color_manual(name = "Línea", values = colors_metro_manual) +
  scale_size(guide = "none") +
  scale_fill_viridis_d(name = "Clúster") +
  coord_sf(xlim = c(-70.8, -70.5), ylim = c(-33.3, -33.65)) +
  guides(
    color = guide_legend(override.aes = list(size = 5)),
    fill = guide_legend(override.aes = list(size = 5))
  ) +
  theme(legend.position = "right")

pmetro2



# https://stackoverflow.com/a/46221054/829971
remove_geom <- function(ggplot2_object, geom_type) {
  # Delete layers that match the requested type.
  layers <- lapply(ggplot2_object$layers, function(x) {
    if (class(x$geom)[1] == geom_type) {
      NULL
    } else {
      x
    }
  })
  # Delete the unwanted layers.
  layers <- layers[!sapply(layers, is.null)]
  ggplot2_object$layers <- layers
  ggplot2_object
}

list(p0, p1, p2, pcors, pnet, pumapkm, pkm,
     pdend, pphylo, pclus, pmetro, pmetro2) |>
  map(function(p){

    pb <- ggplot_build(p)

    nfacets <- pb$layout$layout$PANEL |> length()

    p <- remove_geom(p, "GeomTextRepel") +
      theme(
        panel.grid.major = element_blank(),
        axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        legend.position = "none",
        strip.text = element_blank(),
        panel.spacing = unit(0.1, "lines")

      ) +
      labs(x = NULL, y = NULL, title = NULL, subtitle = NULL)


    if(!class(pb$layout$coord)[1] == "CoordSf") {
      p <- p +  coord_cartesian()
    }

    if(nfacets != 1){
      p <- p +
        # ggforce::facet_grid_paginate(vars(cluster),  ncol = 1, nrow = 1, page = 1)
        facet_wrap(vars(cluster), ncol = 2, scales = "free")
    }

    p

  }) |>
  reduce(`+`)

