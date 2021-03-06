# Fase III 
# Durante la fase III, se leen los archivos .csv que contienen los walksheds
# y se les transforma a objetos espaciales, para luego exportarlos a formato walkshed.shp.
# El script se compone de un loop que:
# Por cada ciudad:
#  - Se ejecuta una funci�n llamada conversor_OTP por cada walkshed de la ciudad, 
#    la cual transforma un objeto GeoJSON a SpatialPolygonsDataframe.
#  - Se exportan los resultados a formato walkshed.shp, para almacenamiento y posterior uso.

library(geojsonio);library(rjson); library(raster); library(rgdal)

# Funci�n que convierte de geojson texto, a objeto espacial

conversor_OTP <- function(walkshed.texto){
  
  # Algunos objetos vienen con una tercera coordenadas "0.0". Esta l�nea la elimina.
  walkshed.texto <- gsub(",0.0", "", walkshed.texto)
  
  # Transformar el objeto texto a json
  walkshed.geojson <- fromJSON(walkshed.texto)
  
  # Dado los problemas que genera esta coordenada Z, algunos polygonos quedan mal clasificados.
  # Por ello, implement� un m�todo para abordar los dos tipos de clasificaciones que se producen de forma aleatoria
  
  # Tipo 1: Si el pol�gono tiene m�s de dos coordenadas, entonces se procede de forma normal.
  if (length(walkshed.geojson$coordinates[[1]]) > 2) {
    # Transforma el objeto a geojson, y luego a objeto SpatialPolygonsDataFrame
    walkshed.polygon <- geojson_list(walkshed.geojson$coordinates[[1]], geometry = "polygon") %>% geojson_sp
  }    
  else {
    # Hay casos donde la API arroja un LineString (ie: el �ltimo vertice es distinto al primero)
    # Este bloque de "if/else" intenta corregirlo al copiar el primer punto y a�adirlo despu�s del �ltimo
    if (!(walkshed.geojson$coordinates[[1]][1] == walkshed.geojson$coordinates[[length(walkshed.geojson$coordinates)]][1] &
          walkshed.geojson$coordinates[[1]][2] == walkshed.geojson$coordinates[[length(walkshed.geojson$coordinates)]][2])){
      walkshed.geojson$coordinates[[length(walkshed.geojson$coordinates)+1]] <- walkshed.geojson$coordinates[[1]]
    }
    # Se imprime un mensaje se�alando que se detecto un LinString, y luego se ejecuta
    # La conversion de GeoJSON a SpatialPolygonsDataframe
    print("LineString detected. Correcting")
    walkshed.polygon <- geojson_list(walkshed.geojson$coordinates, geometry = "polygon") %>% geojson_sp
  }
  return(walkshed.polygon)
}


##### Ejecuci�n de la funci�n. #####

# Definir las carpetas de trabajo: D�nde est�n los archivos de los centroides, los walksheds
# y d�nde se almacenar�n los archivos resultantes.
walkshed.text.carpeta <- "E:/Cedeus Sustainability Indicators/GIS/Areas Verdes/Walksheds GeoJSON/"
centroides.carpeta <- "E:/Cedeus Sustainability Indicators/GIS/Areas Verdes/Centroides_Manzanas/"
walkshed.shp.carpeta <- "E:/Cedeus Sustainability Indicators/GIS/Areas Verdes/Walksheds (Manzanas)/UnDissolved"
# Archivo .csv que contiene los centroides de las manzanas para todas las ciudades.
centroides <- read.csv(paste(centroides.carpeta, "Centroides_Manzanas_Ciudades.csv", sep = ""))
# Nombres de las ciudades
ciudades <- unique(centroides$Ciudad)

# Loop para cada ciudad
for (c in seq(ciudades)){
  # Definir la ciudad
  ciudad <- ciudades[c]
  # Los centroides de esa ciudad, los cuales poseen el ID de cada manzana.
  centroides.ciudad <- centroides[centroides$Ciudad == ciudad,]
  # archivo csv que contiene los pol�gonos en formato GeoJson
  walkshed.text <- read.csv(paste(walkshed.text.carpeta, ciudad, "_walksheds_text.csv", sep = ""))
  # Una lista donde se almacenar� cada pol�gono
  walkshed.shp <- list()
  # Loop para transformar a objetos espaciales.
  for (i in seq(nrow(walkshed.text))){
    print(paste("Pol�gono n�mero:", i, "de", nrow(walkshed.text)))
    # Si el pol�gono no es v�lido (java.lang.NullPointerException null), se ignora. 
    # Estos son casos de manzanas cuyos centroides se encuentran alejados de cualquier red.
    if (grepl("java.lang.NullPointerException null", walkshed.text$walkshed.text[i])){print("Datos inv�lidos. Ignorando"); next()}
    # Se ejecuta la funci�n conversor_OTP.
    walkshed.poligono <- conversor_OTP(walkshed.text$walkshed.text[i])
    # Si el pol�gono tiene un �rea 0 (en caso de ser l�nea, por ejemplo), se ignora.
    if (walkshed.poligono@polygons[[1]]@area == 0){ next()}
    # Se adjunta un identificador al pol�gono resultante, para homogolarlo con las manzanas.
    walkshed.poligono@data$ID <- centroides.ciudad$ID[i]
    # Se adjunta el nombre de la ciudad
    walkshed.poligono@data$properties <- ciudad
    # Se adjunta el pol�gono a la lista de pol�gonos que posteriormente ser� transformada en un
    # objeto �nico. Algo similar a un "join", o "merge"
    walkshed.shp <- append(walkshed.shp, walkshed.poligono)
  }
  # Consolidaci�n de todos los pol�gonos como un solo objeto.
  walkshed.shp <- do.call(bind, walkshed.shp)
  print("Conversi�n exitosa. Exportando a shp.")
  # Exportaci�n de dicho objeto en formato shp.
  writeOGR(obj = as(walkshed.shp, "SpatialPolygonsDataFrame" ), dsn = walkshed.shp.carpeta, 
           layer = paste(ciudad, "_Walksheds_10min (UnDissolved)", sep = ""),
           driver = "ESRI Shapefile",overwrite_layer=TRUE)
}
# Limpiar el ambiente
rm(list=ls())
