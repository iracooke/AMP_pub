Create the train and test set
================

## Data preparation

Read in positive (tg) and negative (bg) data and add y variable label

``` r
tg <- read_faa("cache/positive032020_98.fasta") %>%
  add_column(Label = "Tg")

bg <- read_faa("raw_data/swissprot_all_MAY98.fasta") %>%
  add_column(Label = "Bg")
```

Filter the background dataset using similar criteria to how the positive
dataset in `01_collate_databases.Rmd` got filtered:

  - Remove non standard amino acids
  - Remove proteins between 20 and 700 amino acids long

and also,

  - remove sequences in the background dataset that are present in the
    positive dataset
  - obtain a random subset of the filtered background dataset that match
    the number of rows in the positive dataset

<!-- end list -->

``` r
bg <- bg %>% 
  remove_nonstandard_aa() %>%
  filter(between(nchar(seq_aa),20,700)) %>%
  filter(!seq_aa %in% tg$seq_aa) %>%
  sample_n(nrow(tg))
```

Combine positive and negative datasets

``` r
bg_tg <- rbind(bg, tg)
rownames(bg_tg) <- NULL
```

Calculate features

``` r
features <- ampir:::calculate_features(bg_tg)
```

add Label column for y variable

``` r
features$Label <- as.factor(bg_tg$Label)
```

## Train model

Split feature set data 80/20 and create train and test set

``` r
trainIndex <-createDataPartition(y=features$Label, p=.8, list = FALSE)
featuresTrain <-features[trainIndex,]
featuresTest <-features[-trainIndex,]
```

Normalise data and train a support vector machine model with radial
kernel (rSVM) using repeated cross validation as a resampling method and
add in probability calculation

``` r
rsvm98 <- train(Label~.,
                       data = featuresTrain[,-c(1,27:45)],
                       method="svmRadial",
                       trControl = trainControl(method = "repeatedcv",
                            number = 10, repeats = 3,
                            classProbs = TRUE), 
                       preProcess = c("center", "scale"))
```

## Test model

Use model to classify proteins in the test set and calculation confusion
matrix

``` r
test_pred <- predict(rsvm98, featuresTest)
confusionMatrix(test_pred, featuresTest$Label, positive = "Tg", mode = "everything")
```

Use the probability scores from the model prediction and calculate the
AUROC

``` r
test_pred_prob <- predict(rsvm98, featuresTest, type = "prob")
roc(featuresTest$Label, test_pred_prob$Tg)
```