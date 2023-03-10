# immTagCo

## Description

immTagCo, short for "immediate Tag Completion", is a Vim plugin that inserts
the closing tag of an HTML element at the moment the user finishes writing the
opening tag.

It was made to be fast and easy to use.

## How to Install

To starting using immTagCo, install it with your favorite plugin manager.

To install the plugin with the Vim pack feature, clone this repository to a 
folder inside the Vim packages folder, e.g. 
".vim/pack/plugins/start/immTagCo/":

```
git clone https://github.com/victorspt/immTagCo.git .vim/pack/plugins/start/immTagCo/
```

To install the plugin manually, follow these three steps.
- Step 1: create a folder for the plugin inside the Vim package
folder, e.g. ".vim/pack/plugins/start/immTagCo/".
- Step 2: inside the folder created in the previous step, create a folder 
named "plugin".
- Step 3: copy the main plugin file, "./plugin/immTagCo.vim", into the 
"plugin" folder created in the previous step. The path to the main plugin 
file should look like ".vim/pack/plugins/start/immTagCo/plugin/immTagCo.vim".

## How to Use

The plugin automatically adds the closing tag for HTML elements as soon as 
the opening tag is written.

### Options

There are a few global variables in Vim that control how the plugin behaves.

`g:turnOffImmTagCo`

Default value: "0"

This variable is used to turn the plugin off when it is assigned the value of 
"1". The default value of "0" is used to keep the plugin turned on.

