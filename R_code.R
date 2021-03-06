#Cargando librerías
library(readxl) #Lectura de los datos
library(purrr) #Cambios de formato
library(psych) #Descriptiva 
library(dplyr) #Manipulación de datos
library(forcats) #Explicitación de NAs
library(lubridate) #Manipulación de fechas
library(ggplot2) #Gráficos
library(ggthemes) #Temas de fondo gráficos
library(viridis) #Paletas de colores gráficos
library(naniar) #Estadísticos datos faltantes
library(nortest) #Test de Kolmogorov-Smirnov 
library(car) #Test de Levene y de multicolinealidad
library(coin) #Test de Mann-Whitney-Wilcoxon
library(rstatix) #Tamaño del efecto
library(OptimalCutpoints) #Puntos de corte óptimos 
library(pROC) #Curvas ROC
library(verification) #Significación AUC
library(MASS) #Modelos de regresión logística
library(ResourceSelection) #Test de Hosmer & Lemeshow
library(ROSE) #Método de remuestreo ROSE
library(InformationValue) #Punto de corte de predicción óptimo
library(caret) #Matriz de confusión

#Leyendo los datos
datos <- read_excel("./BD.xlsx")[ ,1:16]
glimpse(datos)

#Cambiando el formato de las variables
datos[,c(1:5,7)] <- map_df(datos[,c(1:5,7)], as.factor) #de character a factor
str(datos) #Ahora, todas las variables están en el formato correcto

#MATERIAL Y MÉTODOS
#Evolución temporal TR/CE
temporal_instalacion <- datos %>%
  mutate(instalacion = case_when(CLAVE %in%  c("AM-1", "AM-2", "BI(CE)", "CAP(CE)", "CEF(CE)-1", "CEF(CE)-2",
  "CEF(CE)-3", "CEF(CE)-4", "MC(CE)", "MC(CE)-1", "MC(CE)-2", "MC(CE)-3", "MEC(CE)-1", "MEC(CE)-2", "MEC(CE)-3",
  "MEC(CE)-4", "MEC(CE)-7", "MEC(CE)-8", "MEC(CE)-9", "MEC(CE)-10", "MEC(CE)-11", "MEC(CE)-12") ~ "CE", TRUE ~ "TR")) %>%
  group_by(year(FECHA), instalacion) %>%
  summarize(n = length(unique(CLAVE)))

ggplot(temporal_instalacion, aes(x = `year(FECHA)`)) + geom_bar(aes(y = n, fill = instalacion), 
  stat="identity") + scale_fill_manual("Tipo de instalación", values = c("TR" = "brown4", "CE" = "darkgreen")) +
  labs(x = "Fecha (año)", y = "TR/CE") + scale_x_continuous(breaks = year(datos$FECHA)) + 
  scale_y_continuous(breaks = seq(from = 0, to = 55, by = 5)) + theme(axis.line = 
  element_line(colour = "black"), panel.background = element_blank(), legend.key = 
  element_rect(fill = "white"), legend.position = "bottom", axis.title.y.left = element_text(face = "bold"), 
  axis.title.y.right = element_text(face = "bold"), axis.title.x = element_text(face = "bold")) + theme_hc() 

#Evolución temporal del número de muestras tomadas en TR/CE y actividades con TR/CE
datos %>%
  group_by(year(FECHA)) %>%
  summarize(muestras = n(), actividades = length(unique(CCAE)))

#Seleccionamos las filas corespondientes a aquellas instalaciones en las que se ha hecho el recuento de Legionella
datos <- datos[which(complete.cases(datos$RECUENTO_LEGIONELLA)), ]

#1. ANÁLISIS DESCRIPTIVO
#Muestras tomadas en TR/CE ubicadas en Hospitalet vs. fuera
addmargins(table(datos$EN_HOSPITALET, datos$INSTALACION))
round(addmargins(prop.table(table(datos$EN_HOSPITALET, datos$INSTALACION)))*100,2)

#Parámetros microbiológicos y fisicoquímicos 
psych::describe(datos[,c(6, 8:15)], IQR = T)[ ,c(2, 5, 8, 9, 14)]

#Boxplots
par(mfrow = c(3, 3))
for (i in 1:length(datos[, c(6, 8:15)])){
  ylab <- c("UFC/l", "UFC/ml", "", expression(mu*"S/cm"), "UNF", "mg/l", "mg/l", "mg/l", "")
  colnames <- c("Recuento de Legionella", "Aerobios totales", "pH", "Conductividad",
  "Turbidez", "Hierro total", "Alcalinidad", "Dureza", "Índice de Langelier")
  boxplot(datos[, c(6, 8:15)][, i], ylab = ylab[i], main = paste(colnames[i], sep = " "),
  col = "chartreuse4")
}

#1.1. POSITIVOS DE LEGIONELLA
#Valores mínimo y máximo del recuento de Legionella
datos %>% 
  filter(RECUENTO_LEGIONELLA > 0) %>%
  summarise(mínimo = min(RECUENTO_LEGIONELLA), máximo = max(RECUENTO_LEGIONELLA)) #mínimo = 25, máximo = 15000000

#Tabla recuento de Legionella por serogrupos
datos %>% 
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  group_by(fct_explicit_na(SEROGRUPO)) %>%
  summarise("<100" = sum(RECUENTO_LEGIONELLA < 100), "100-1,000" = sum(RECUENTO_LEGIONELLA >= 100 & 
  RECUENTO_LEGIONELLA < 1000), "1,000-10,000" = sum(RECUENTO_LEGIONELLA >= 1000 & RECUENTO_LEGIONELLA < 10000), 
  ">10,000" = sum(RECUENTO_LEGIONELLA >= 10000), n = n()) %>%
  mutate(freq = paste0(round(100 * n/sum(n), 2), "%"))

#Evolución anual de los positivos y el recuento medio de Legionella
anual <- datos %>%
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  group_by(year(FECHA)) %>%
  summarise(n_1 = n(), n_2 = mean(RECUENTO_LEGIONELLA))
#Incluimos los años del periodo comprendido entre 2017 y 2019, en los que no se hallaron positivos de
#Legionella, para poder graficarlos
anual <- anual %>% add_row(`year(FECHA)`= c(2017, 2018, 2019), n_1 = c(0,0,0), n_2 = c(0,0,0))

#Relación entre la evolución anual de los positivos de Legionella y el recuento medio anual de Legionella
ggplot(anual, aes(x = `year(FECHA)`)) + geom_line(aes(y = n_1), size = 0.8, 
  color = "#000033") + geom_line(aes(y = n_2/55000), size = 0.8, colour = "#CC3366") +
  geom_point(aes(y = n_1), size = 2.5, color = "#000033", shape = 18) + geom_point(aes(y = 
  n_2/55000), size = 2.5, colour = "#CC3366", shape = 20) +
  geom_vline(aes(xintercept=2003, linetype=""), size = 0.8, color = "burlywood4") +
  scale_x_continuous(breaks = year(datos$FECHA)) + scale_y_continuous(breaks = 
  seq(from = 0, to = 22, by = 2), sec.axis = sec_axis(~.*55000, name = "Recuento medio de Legionella (UFC/l)", 
  breaks = seq(from = 0, to = max(anual$n_2), by = 100000), labels = c("0", expression("10x"*10^4), expression("20x"*10^4),
  expression("30x"*10^4), expression("40x"*10^4), expression("50x"*10^4), expression("60x"*10^4), expression("70x"*10^4), 
  expression("80x"*10^4), expression("90x"*10^4), expression("10x"*10^5), expression("11x"*10^5), expression("12x"*10^5)))) + 
  labs(y = "Positivos de Legionella", x = "Fecha (año)", 
  title = "") + scale_linetype_manual(name = "RD 865/2003", values = "dashed") +
  theme(axis.line = element_line(colour = "black"), panel.background = element_blank(), 
  legend.key = element_rect(fill = "white"), legend.position = "bottom", axis.title.y.left = 
  element_text(color = "#000033", face = "bold"), axis.title.y.right = element_text(color = "#CC3366", 
  face = "bold"), axis.title.x = element_text(face = "bold")) + theme_hc()

#1.2. ESTACIONALIDAD DE LOS POSITIVOS
#Evolución mensual de los positivos de Legionella 
positivos_mes <- datos %>%
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  mutate(estacion = case_when(month(FECHA) %in%  c(12,1,2)  ~ "Invierno", month(FECHA) %in%  3:5  ~ "Primavera",
  month(FECHA) %in% 6:8 ~ "Verano", TRUE ~ "Otoño")) %>%
  group_by(month(FECHA), estacion) %>%
  summarise(n = n()) %>%
  mutate(freq = paste0(round(100 * n/sum(n), 2), "%"))

ggplot(positivos_mes, aes(x = `month(FECHA)`)) + geom_bar(aes(y = n, fill = estacion), 
  stat="identity", color = "black") + geom_text(aes(y = n, label = paste0(n, "\n(", round(100*n/sum(n), 2), "%", ")")), 
  vjust = 1.4, size = 3.5, color = "white") + scale_fill_manual(values = c("#663333", "#993333", "#CC3333", "#FF3333")) +
  scale_x_continuous(breaks = month(datos$FECHA), labels = month(datos$FECHA, label=T, abbr=F)) +
  scale_y_continuous(breaks = seq(from = 0, to = 9)) + labs(y = "Positivos de Legionella", x = 
  "Fecha (mes)", title = "", fill = "Estación") + 
  theme(axis.line = element_line(colour = "black"), legend.position = "none", panel.background = 
  element_blank(), axis.title.y.left = element_text(face = "bold"), axis.title.x = element_text(face = "bold"),
  axis.text.x = element_text(angle = 45, hjust = 1)) + theme_hc()

#Positivos y serogrupo Pneumophila por estación
datos%>%
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  mutate(estacion = case_when(month(FECHA) %in%  c(12,1,2)  ~ "Invierno", month(FECHA) %in%  3:5  ~ "Primavera",
  month(FECHA) %in% 6:8 ~ "Verano", TRUE ~ "Otoño"), serogrupos = case_when(SEROGRUPO %in% 
  c("1", "2 a 14", "1 y 2 a 14") ~ "Pneumophila", TRUE ~ "No Pneumophila")) %>%
  group_by(estacion) %>%
  summarise(positivos = n(), Pneumophila = sum(serogrupos == "Pneumophila"), Recuento_media = 
  mean(RECUENTO_LEGIONELLA), Recuento_s = sd(RECUENTO_LEGIONELLA)) %>%
  mutate(freq_positivos = paste0(round(100 * positivos/sum(positivos), 2), "%"), freq_Pneumophila = 
  paste0(round(100 * Pneumophila/positivos, 2), "%"))

#1.3. POSITIVOS POR UBICACIÓN Y ACTIVIDAD 
#Positivos de Legionella por ubicación
datos %>%
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  group_by(EN_HOSPITALET) %>%
  summarise(n = n()) %>%
  mutate(freq = paste0(round(100 * n/sum(n), 2), "%"))

#Positivos de Legionella por actividad (CCAE)
datos %>%
  filter(RECUENTO_LEGIONELLA >= 25) %>%
  group_by(CCAE) %>%
  summarise(n = n()) %>%
  mutate(freq = paste0(round(100 * n/sum(n), 2), "%")) %>%
  ggplot(aes(x = "",y = n, fill = CCAE)) + geom_bar(stat = "identity", color = "white") + 
  geom_text(aes(label = paste0(n, " (", round(100*n/sum(n), 2), "%", ")"), x =1.28), position = position_stack(vjust = 0.5), color = "white") +
  coord_polar(theta = "y", start = 4) + theme_void() + scale_fill_viridis(option = "cividis", discrete=T) +
  labs(title = "", fill = "Actividad (CCAE)") 

#2. ANÁLISIS BIVARIANTE
datos <- datos[ ,c(6,8:15)] #Seleccionamos los datos de parámetros microbiológicos y físico-químicos

#VALORACIÓN DE LOS DATOS FALTANTES
#Hay NAs en la base de datos?
any_na(datos) #Sí
#Cuántos NAs hay en total?
n_miss(datos) #2512
paste0(round(prop_miss(datos)*100, 2), "%") #Proporción total de NAs = 35.38% 
#Número de NAs por variable
colSums(is.na(datos))
#Proporción de NAs por variable
for (i in 1: length(datos[,-9])){
  print(names(datos[,-9][i]))[i]
  print(paste0(round(prop_miss(datos[ ,-9][, i])*100, 2), "%"))
} #La variable Índice de Langelier es la que presenta más NAs, y los aerobios totales la que menos
vis_miss(datos[,-9], sort = T, show_perc = F, show_perc_col = F) #Visualización

#2.1. CORRELACIONES (SPEARMAN) 
#Test de normalidad: Kolmogorov-Smirnov (corrección de Lilliefors)
apply(datos, 2, lillie.test)

#Coeficientes de correlación de Spearman entre las variables objeto de estudio
round(cor(datos, use= "pairwise.complete.obs", method = "spearman"), 2)
#Significación de las correlaciones entre las variables objeto de estudio
apply(datos, 2, cor.test, datos$RECUENTO_LEGIONELLA, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$AEROBIOS_TOTALES, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$PH, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$CONDUCTIVIDAD, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$TURBIDEZ, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$HIERRO, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$ALCALINIDAD, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$DUREZA, method = "spearman", exact=FALSE)
apply(datos, 2, cor.test, datos$INDICE_LANGELIER, method = "spearman", exact=FALSE)

#2.2. COMPARACIONES DE 2 GRUPOS INDEPENDIENTES (TEST U DE MANN-WHITNEY-WILCOXON)
#Creamos la variable PRESENCIA_LEGIONELLA, codificando el RECUENTO_LEGIONELLA como 0 si < 25 UFC/l
#y como 1 si >= 25 UFC/l
datos <- cbind(datos[, 2:9], as.factor(ifelse(datos$RECUENTO_LEGIONELLA >= 25, 1, 0)))
colnames(datos)[9] <- "PRESENCIA_LEGIONELLA"

#Tests de normalidad Shapiro-Wilk (n <= 50) y Kolmogorov-Smirnov (corrección de Lilliefors) (n > 50)
for (i in 1:length(datos[ ,-9])){
  if(length(subset(datos[which(complete.cases(datos[ ,i])), ], PRESENCIA_LEGIONELLA == 1)[ ,i]) > 50) {
    print(paste("Test de normalidad Kolmogorov-Smirnov", names(datos[i])))[i]
    print(lillie.test(subset(datos, PRESENCIA_LEGIONELLA == 1)[ ,i]))
  }else{
    print(paste("Test de normalidad Shapiro-Wilk", names(datos[i])))[i]
    print(shapiro.test(subset(datos, PRESENCIA_LEGIONELLA == 1)[ ,i]))}
      if(length(subset(datos[which(complete.cases(datos[ ,i])), ], PRESENCIA_LEGIONELLA == 0)[ ,i]) > 50) {
        print(paste("Test de normalidad Kolmogorov-Smirnov", names(datos[i])))[i]
        print(lillie.test(subset(datos, PRESENCIA_LEGIONELLA == 0)[ ,i]))
      }else{
        print(paste("Test de normalidad Shapiro-Wilk", names(datos[i])))[i]
        print(shapiro.test(subset(datos, PRESENCIA_LEGIONELLA == 0)[ ,i]))}}

#Tests de homocedasticidad de Levene
lapply(datos[,-9], function(x) leveneTest(x ~ datos$PRESENCIA_LEGIONELLA))

#Test de comparación de medianas de Wilcoxon
lapply(datos[,-9], function(x) coin::wilcox_test(x ~ datos$PRESENCIA_LEGIONELLA))

#Tamaño del efecto
wilcox_effsize(datos, AEROBIOS_TOTALES ~ PRESENCIA_LEGIONELLA) #r = 0.11
#o 2.5333/sqrt(24 + 556) (tamaño_efecto <- |Z|/sqrt(n1 + n2))
wilcox_effsize(datos, PH ~ PRESENCIA_LEGIONELLA) #r = 0.08 
wilcox_effsize(datos, CONDUCTIVIDAD ~ PRESENCIA_LEGIONELLA) #r = 0.05 
wilcox_effsize(datos, TURBIDEZ ~ PRESENCIA_LEGIONELLA) #r = 0.02 
wilcox_effsize(datos, HIERRO ~ PRESENCIA_LEGIONELLA) #r = 0.01 
wilcox_effsize(datos, ALCALINIDAD ~ PRESENCIA_LEGIONELLA) #r = 0.01 
wilcox_effsize(datos, DUREZA ~ PRESENCIA_LEGIONELLA) #r = 0.06
wilcox_effsize(datos, INDICE_LANGELIER ~ PRESENCIA_LEGIONELLA) #r = 0.14

#Estadísticos de resumen
for (i in 1:length(datos[,-9])){
  print(names(datos[i]))[i]
  print(datos %>%
  dplyr::filter(complete.cases(datos[,i])) %>%
  dplyr::group_by(PRESENCIA_LEGIONELLA) %>%
  dplyr::summarise(n = n()))
} #n
datos %>%
  group_by(PRESENCIA_LEGIONELLA) %>%
  summarise_each(list(Mediana = ~ median(., na.rm = T), IQR = ~ IQR(., na.rm = T))) #Mediana e IQR

#Gráficos de caja 
par(mfrow = c(2, 4))
for (i in 1: length(datos[,-9])) {
  ylab <- c("UFC/ml", "", expression(mu*"S/cm"), "UNF", "mg/l", "mg/l", "mg/l", "")
  colnames <- c("Aerobios totales", "pH", "Conductividad", "Turbidez", "Hierro total", "Alcalinidad", 
  "Dureza", "Índice de Langelier")
  boxplot(datos[,-9][, i] ~ datos$PRESENCIA_LEGIONELLA, col = c("burlywood4", "brown2"), 
  xlab = "", ylab = ylab[i], names = c("Ausencia de \nLegionella", "Presencia de \nLegionella"), 
  main = paste(colnames[i], sep = " "))
}

#3. PUNTOS DE CORTE ÓPTIMOS (CURVAS ROC)
for (i in 1:length(datos[ ,-9])){
  print(paste("Punto de corte óptimo", names(datos[i])))[i]
  print(summary(optimal.cutpoints(names(datos[-9])[i], status = "PRESENCIA_LEGIONELLA", tag.healthy = 0, 
  methods = "Youden", data = datos, pop.prev = NULL, ci.fit = TRUE, conf.level = 0.95, control = control.cutpoints())))
  print(paste("Significación AUC", names(datos[i])))[i]
  print(roc.area(as.numeric(as.vector(datos$PRESENCIA_LEGIONELLA)), datos[ ,i])$p.value)  
}

#Gráfico curvas ROC
roc_curve <- lapply(datos[ ,-9], function(x) roc(datos$PRESENCIA_LEGIONELLA, x, auc = T, ci = T, direction = "<"))

ggroc(list("Aerobios \ntotales" = roc_curve$AEROBIOS_TOTALES, "pH" = roc_curve$PH, "Conductividad" = 
  roc_curve$CONDUCTIVIDAD, "Turbidez" = roc_curve$TURBIDEZ, "Hierro total" = roc_curve$HIERRO,
  "Alcalinidad" = roc_curve$ALCALINIDAD, "Dureza" = roc_curve$DUREZA, "Índice de \nLangelier" = 
  roc_curve$INDICE_LANGELIER), size = 1) + geom_abline(aes(intercept = 1, slope = 1), color = "burlywood4", size = 0.8) + 
  geom_point(aes(x = 0.509, y = 0.875), colour = "#FF3300", size = 2.3) + 
  geom_point(aes(x = 0.602, y = 0.609), colour = "chartreuse4", size = 2.3) + 
  geom_point(aes(x = 0.468, y = 0.783), colour = "darkblue", size = 2.3) +
  geom_point(aes(x = 0.943, y = 0.227), colour = "darkgoldenrod3", size = 2.3) +
  geom_point(aes(x = 0.916, y = 0.261), colour = "darkorange", size = 2.3) +
  geom_point(aes(x = 0.450, y = 0.696), colour = "brown", size = 2.3) +
  geom_point(aes(x = 0.680, y = 0.565), colour = "blueviolet", size = 2.3) + 
  geom_point(aes(x = 0.698, y = 0.652), colour = "deeppink3", size = 2.3) + 
  annotate("text", x = 0.509, y = 0.885, vjust = 0, label = 100, col = "#FF3300") +  
  annotate("text", x = 0.602, y = 0.619, vjust = 0, label = 8.70, col = "chartreuse4") +
  annotate("text", x = 0.468, y = 0.793, vjust = 0, label = 2950, col = "darkblue") +
  annotate("text", x = 0.943, y = 0.237, vjust = 0, label = 27.80, col = "darkgoldenrod3") +
  annotate("text", x = 0.916, y = 0.271, vjust = 0, label = 1.83, col = "darkorange") +
  annotate("text", x = 0.450, y = 0.706, vjust = 0, label = 354, col = "brown") +
  annotate("text", x = 0.680, y = 0.575, vjust = 0, label = 572, col = "blueviolet") +
  annotate("text", x = 0.698, y = 0.662, vjust = 0, label = 1.90, col = "deeppink3") +
  scale_x_reverse(name = "1 - Especificidad") + scale_y_continuous(name = "Sensibilidad") + annotate("text", 
  x = 0.37, y = 0.35, vjust = 0, hjust = 0, label = paste0("AUC Aerobios totales = ", round(auc(roc_curve$AEROBIOS_TOTALES), 2)), col = "#FF3300") +
  annotate("text", x = 0.37, y = 0.3, vjust = 0, hjust = 0, label = paste0("AUC pH = ", round(auc(roc_curve$PH), 2)), 
  col = "chartreuse4") + annotate("text", x = 0.37, y = 0.25, vjust = 0, hjust = 0, label = paste0("AUC Conductividad = ", 
  round(auc(roc_curve$CONDUCTIVIDAD), 2)), col = "darkblue") + annotate("text", x = 0.37, y = 0.2, vjust = 0, hjust = 0, label = 
  paste0("AUC Turbidez = ", round(auc(roc_curve$TURBIDEZ), 2)), col = "darkgoldenrod3") + annotate("text", x = 0.37, y = 0.15, 
  vjust = 0, hjust = 0, label = paste0("AUC Hierro total = ", round(auc(roc_curve$HIERRO), 2)), col = "darkorange") + annotate("text", 
  x = 0.37, y = 0.1, vjust = 0, hjust = 0, label = paste0("AUC Alcalinidad = ", round(auc(roc_curve$ALCALINIDAD), 2)), col = "brown") +
  annotate("text", x = 0.37, y = 0.05, vjust = 0, hjust = 0, label = paste0("AUC Dureza = ", round(auc(roc_curve$DUREZA), 2)), col = "blueviolet") +
  annotate("text", x = 0.37, y = 0, vjust = 0, hjust = 0, label = paste0("AUC Índice de Langelier = ", round(auc(roc_curve$INDICE_LANGELIER), 2)), 
  col = "deeppink3") + scale_color_manual(values = c("#FF3300", "chartreuse4", "darkblue", "darkgoldenrod3",
  "darkorange", "brown", "blueviolet", "deeppink3")) + theme(axis.line = element_line(colour = "black"), panel.background = element_blank(), 
  legend.key = element_rect(fill = "white"), legend.position = "none", legend.title = element_blank(), 
  axis.title.y.left = element_text(face = "bold"), axis.title.y.right = element_text(face = "bold"), 
  axis.title.x = element_text(face = "bold"))                                                                                         

#4. ANÁLISIS DE REGRESIÓN LOGÍSTICA
#4.1. ANÁLISIS UNIVARIANTE: PRESELECCIÓN DE VARIABLES PREDICTORAS
#Primero, discretizamos los predictores
datos$AEROBIOS_TOTALES <- as.factor(ifelse(datos$AEROBIOS_TOTALES >= 100, 1, 0))
datos$PH <- as.factor(ifelse(datos$PH >= 8.7, 1, 0))
datos$CONDUCTIVIDAD <- as.factor(ifelse(datos$CONDUCTIVIDAD >= 2950, 1, 0))
datos$TURBIDEZ <- as.factor(ifelse(datos$TURBIDEZ >= 27,80, 1, 0))
datos$HIERRO <- as.factor(ifelse(datos$HIERRO >= 1,83, 1, 0))
datos$ALCALINIDAD <- as.factor(ifelse(datos$ALCALINIDAD >= 354, 1, 0))
datos$DUREZA <- as.factor(ifelse(datos$DUREZA >= 572, 1, 0))
datos$INDICE_LANGELIER <- as.factor(ifelse(datos$INDICE_LANGELIER >= 1.90, 1, 0))

#ANÁLISIS DE REGRESIÓN LOGÍSTICA UNIVARIANTES
#Aerobios totales
glm_Aerobios <- glm(PRESENCIA_LEGIONELLA ~ AEROBIOS_TOTALES, data = datos, family = binomial(link = "logit"))
summary(glm_Aerobios)
round(exp(cbind(OR = coef(glm_Aerobios), confint(glm_Aerobios))), 2) #OR e IC(95%)

#pH
glm_pH <- glm(PRESENCIA_LEGIONELLA ~ PH, data = datos, family = binomial(link = "logit"))
summary(glm_pH)
round(exp(cbind(OR = coef(glm_pH), confint(glm_pH))), 2) 

#Conductividad
glm_Conductividad <- glm(PRESENCIA_LEGIONELLA ~ CONDUCTIVIDAD, data = datos, family = binomial(link = "logit"))
summary(glm_Conductividad)
round(exp(cbind(OR = coef(glm_Conductividad), confint(glm_Conductividad))), 2) 

#Turbidez
glm_Turbidez <- glm(PRESENCIA_LEGIONELLA ~ TURBIDEZ, data = datos, family = binomial(link = "logit"))
summary(glm_Turbidez)
round(exp(cbind(OR = coef(glm_Turbidez), confint(glm_Turbidez))), 2) 

#Hierro total
glm_Hierro <- glm(PRESENCIA_LEGIONELLA ~ HIERRO, data = datos, family = binomial(link = "logit"))
summary(glm_Hierro)
round(exp(cbind(OR = coef(glm_Hierro), confint(glm_Hierro))), 2) 

#Alcalinidad
glm_Alcalinidad <- glm(PRESENCIA_LEGIONELLA ~ ALCALINIDAD, data = datos, family = binomial(link = "logit"))
summary(glm_Alcalinidad)
round(exp(cbind(OR = coef(glm_Alcalinidad), confint(glm_Alcalinidad))), 2)

#Dureza
glm_Dureza <- glm(PRESENCIA_LEGIONELLA ~ DUREZA, data = datos, family = binomial(link = "logit"))
summary(glm_Dureza)
round(exp(cbind(OR = coef(glm_Dureza), confint(glm_Dureza))), 2)

#Índice de Langelier
glm_Langelier <- glm(PRESENCIA_LEGIONELLA ~ INDICE_LANGELIER, data = datos, family = binomial(link = "logit"))
summary(glm_Langelier)
round(exp(cbind(OR = coef(glm_Langelier), confint(glm_Langelier))), 2) 

#4.2. ANÁLISIS MULTIVARIANTE (MODELO DE REGRESIÓN LOGÍSTICA MÚLTIPLE DE PASOS HACIA ATRÁS)
datos_MLG <- datos[,-c(3:6)][which(complete.cases(datos[,-c(3:6)])), ] #Analizaremos los datos completos 

null <- glm(PRESENCIA_LEGIONELLA ~ 1, data = datos_MLG, family = binomial(link = "logit")) #Modelo nulo
summary(null) #AIC = 149.77, D = 147.77
full <- glm(PRESENCIA_LEGIONELLA ~ ., data = datos_MLG, family = binomial(link = "logit")) #Modelo completo
step_model <- step(full, direction = "backward", stat = "wald", alpha = 0.05, trace = T) #Técnica stepwise backward
summary(step_model) #Modelo con el menor AIC (120.7) y la menor Devianza (D = 108.7)
round(exp(cbind(OR = coef(step_model), confint(step_model))), 2) #OR e IC(95%)

#SIGNIFICACIÓN GLOBAL DEL MODELO (TEST DE LA RAZÓN DE VEROSIMILITUD)
(dif_residuos <- step_model$null.deviance - step_model$deviance) #Estadístico chi-cuadrado = 39.08
(df <- step_model$df.null - step_model$df.residual) #Grados libertad = 5
pchisq(q = dif_residuos, df = df, lower.tail = F) #p-valor = 0.00 (modelo estadísticamente significativo)
#o lmtest::lrtest(step_model)

#MEDIDAS DE BONDAD DE AJUSTE DEL MODELO
#Devianza
(Dev <- -2*logLik(step_model)) #Devianza = 108.7
#o step_model$deviance 

#AIC
(k <- length(step_model$coefficients)) #número de parámetros del modelo = 6
Dev + 2*k #AIC = 120.7

#Pseudo R^2 (McFadden) 
1 - (step_model$deviance/step_model$null.deviance) #Pseudo R^2  = 0.26 (> 0.2 = buen ajuste del modelo)
#o 1-(logLik(step_model)/logLik(null))
#o pscl::pR2(step_model)

#Prueba de Hosmer-Lemeshow 
hoslem.test(step_model$y, fitted(step_model)) #p-valor = 0.94 (> 0.05 = buen ajuste del modelo)

#Sobredispersión
(phi <- sum(residuals(step_model, type = "deviance")^2) / df.residual(step_model)) #0.32 (no hay sobredispersión)
#o (phi <- Dev / df.residual(step_model))

#4.3. VALIDACIÓN: ANÁLISIS DE LOS RESIDUOS Y DETECCIÓN DE OBSERVACIONES ATÍPICAS 
res_1 <- rstandard(step_model, type = "pearson") #Residuos estandarizados de Pearson
table(abs(res_1) > 2) #8 residuos > 2 (8/351 = 0.02: menos del 5% de los residuos no pertenece al intervalo (-2,2))
res_2 <- rstandard(step_model, type = "deviance") #Residuos estandarizados de la Devianza
table(abs(res_2) > 2) #7 residuos > 2

#Gráfico residuos estandarizados de Pearson y de la Devianza
plot(res_1, col = "blue", xlab = "Observación", ylab = "Residuos estandarizados", pch = 1) #Residuos estandarizados de Pearson
points(res_2, col = "darkred", pch = 1) #Residuos estandarizados de la Devianza
legend(-1,22.5, legend = c("Residuos de Pearson", "Residuos de la Devianza"), col = c("blue", "darkred"), 
  pch = 1, cex = 0.8, box.lty = 0)
abline(h = 2, lty = 2) 

#Medidas de influencia
(n <- dim(datos_MLG)[1]) #n = 351
leverage <- hatvalues(step_model) #Leverage
table(leverage > (2*k/n)) #47 valores con un leverage > 2*k/n
cook <- cooks.distance(step_model) #Distancia de Cook
table(cook > 4/n) #22 residuos con una distancia de Cook > 4/n

#Gráfico residuos estandarizados vs.Leverage
plot(x = leverage, y = res_1, xlab = "Leverage", ylab = "Residuos estandarizados de Pearson") 
abline(v = 2*k/n, h = 2, lty = 2)

#Gráfico distancia de Cook
plot(step_model, which = 4) 
abline(h = 4/n, lty = 2)
#Las observaciones más influyentes son la 215, la 242 y la 738

#Gráfico residuos estandarizados vs. Leverage (+ Distancia de Cook)
plot(step_model, which = 5, ann = FALSE, id.n = 20) 
title(main="", xlab = "Leverage", ylab = "Residuos estandarizados de Pearson")
abline(v = 2*k/n, h = 2, lty = 2)

#Análisis de las observaciones más influyentes
influencePlot(step_model) 
#No se aprecia ninguna observación que tenga una influencia desproporcionada sobre los valores de los coeficientes
#de regresión

#Valor predictivo del modelo
(X <- data.frame(AEROBIOS_TOTALES = "1", PH ="1", TURBIDEZ ="1", DUREZA ="1", INDICE_LANGELIER ="1"))
predict(step_model, newdata = X, type = "response") #p(Y = 1|X) = 0.8248

#4.4. MODELO DE CLASIFICACIÓN
table(datos_MLG$PRESENCIA_LEGIONELLA) #Clases desbalanceadas (0s = 332, 1s = 19)

#Dividimos los datos en los conjuntos de entrenamiento (50%), prueba (25%) y validación (25%)
set.seed(156) 
indices <- 1:n
ient <- sample(indices,floor(n*0.5))
ival <- sample(setdiff(indices,ient),floor(n*0.25))
itest <- setdiff(indices,union(ient,ival))
training <- datos_MLG[ient,] #Conjunto de entrenamiento (50%)
dim(training)
validation <- datos_MLG[ival,] #Conjunto de validación (25%)
dim(validation)
test <- datos_MLG[itest,] #Conjunto de prueba (25%)
dim(test)
training_valid <- rbind(training, validation) #Conjunto de entrenamiento + validación (75%)
dim(training_valid)

#Método de remuestreo ROSE
rose <- ROSE(PRESENCIA_LEGIONELLA ~., data = training, seed = 13)$data #Conjunto de entrenamiento 
table(rose$PRESENCIA_LEGIONELLA) #87/175 (50%): clase 1, 88/175 (50%): clase 0
rose_valid <- ROSE(PRESENCIA_LEGIONELLA ~ ., data = validation)$data #Conjunto de validación
rose_train_valid <- rbind(rose, rose_valid) #Conjunto de entrenamiento + validación
table(rose_train_valid$PRESENCIA_LEGIONELLA) #137/262 (52%): clase 1, 125/262 (48%): clase 0

#Utilizamos el conjunto de entrenamiento para construir el modelo
logitMod <- glm(step_model, data = rose_train_valid, family = binomial(link="logit"))

#Calculamos los valores predichos con el conjunto de prueba
predicted <- predict(logitMod, newdata = test, type = "response") 

#Probabilidad de corte de predicción óptima según el índice de Youden
(optCutOff <- optimalCutoff(validation$PRESENCIA_LEGIONELLA, predicted, returnDiagnostics = T, optimiseFor = "Both")[1]) #0.75
thresholded_predicted <- as.factor(ifelse(predicted > optCutOff, 1, 0))
#thresholded_predicted <- as.factor(ifelse(predicted > 0.5, 1, 0)) punto de corte predeterminado

#Matriz de confusión
(confusion <- as.matrix(caret::confusionMatrix(thresholded_predicted, test$PRESENCIA_LEGIONELLA, positive = '1')))

#Precisión (% observaciones positivas predichas correctamente)
(precision <- caret::precision(thresholded_predicted, test$PRESENCIA_LEGIONELLA, relevant = '1'))
paste0("Precisión del modelo = ", round(100*(precision), 2), "%") #42.86%
#Sensibilidad o recall (% verdaderos positivos)
(recall <- caret::sensitivity(thresholded_predicted,  test$PRESENCIA_LEGIONELLA, positive = '1'))
paste0("Sensibilidad del modelo = ", round(100*(recall), 2), "%") #85.71%
#Exactitud o accuracy (% observaciones predichas correctamente)
paste0("Exactitud del modelo = ", round(100*sum(diag(confusion))/sum(confusion), 2), "%") #89.89% (con el punto de corte predeterminado de 0,50 = 79.78%)
#Puntuación F1:
paste0("Puntuación F1 del modelo = ", round(2*((precision*recall)/(precision+recall)), 2)) #0.57

#Evaluación de la capacidad predictiva del modelo: curva ROC-AUC
(ROC <- roc(test$PRESENCIA_LEGIONELLA, predicted, auc = T)) #AUC = 0.88 (buen modelo de clasificación)

ggroc(ROC, col = "brown2", size = 0.8) + geom_abline(aes(intercept = 1, slope = 1), color = "burlywood4", 
  size = 1) + scale_x_reverse(name = "1 - Especificidad") + scale_y_continuous(name = "Sensibilidad") + 
  annotate("text", x = 0.05, y = 0, vjust = 0, label = paste0("AUC = ", round(auc(ROC), 2)), col = "brown2", 
  size = 5) + theme(axis.line = element_line(colour = "black"), panel.background = element_blank(), legend.key 
  = element_rect(fill = "white"), legend.position = "bottom", legend.title = element_blank(), axis.title.x = 
  element_text(face = "bold"), axis.title.y = element_text(face = "bold"))
