
node model_dir;
node flair_ner{
    # set model configuration and infer entity
    // ent_ext.set_config, can ent_ext.entity_detection;
    can ent_ext.set_config, ent_ext.train, ent_ext.entity_detection;


    can set_config with infer_zero_shot entry{
        report ent_ext.set_config(
            ner_model = visitor.model_name,
            model_type = visitor.model_type
        );
    }
    can train with train_and_val_flair entry{
        # train the model with a given dataset
        train_data = file.load_json(visitor.train_file);
        val_data = file.load_json(visitor.val_file);
        test_data = file.load_json(visitor.test_file);

        # training model
        ent_ext.train(
            train_data = train_data,
            val_data = val_data,
            test_data = test_data,
            train_params = {
                "num_epoch": visitor.num_train_epochs.int,
                "batch_size": visitor.batch_size.int,
                "LR": visitor.learning_rate.float
                });
            std.out(train_data);
        std.out(train_data);
    }

    can infer with predict_flair entry{
        report ent_ext.entity_detection(
            text = visitor.text,
            ner_labels = visitor.ner_labels.list
        );
    }

    can infer_zero_shot with infer_zero_shot entry{
        text = visitor.text;
        labels = visitor.labels.list;
        result =  ent_ext.entity_detection(
            text=text,
            ner_labels= labels
            );
        fn = "result.json";
        result = {"text":text,"entities":result["entities"]};
        file.dump_json(fn, result);
    }
}

# adding edge
// edge ner_model {
//     has model_type;
// }

// graph ner_eval_graph {
//     has anchor ner_model_dir;
//     spawn {
//         ner_model_dir = spawn node::model_dir;
//         flair_ner_node = spawn node::flair_ner;
//         ner_model_dir -[ner_model(model_type="flair_ner")]-> flair_ner_node;
//     }
// }

// walker init {
//     root {
//     spawn here --> graph::ner_val_graph; 
//     }
// }

## creating walker 
walker train_and_val_flair {
    # Take in a training and eval dataset
    has train_file;
    has val_file;
    has test_file;
    has model_name="prajjwal1/bert-tiny";
    has model_type="trfmodel";
    has num_train_epochs=3;
    has batch_size=8;
    has learning_rate=0.02;

    # Train all NER models on the train set
    # and validate them on the val set
    # report accuracy performance on flair NER models
    // root {
    //     take --> node::model_dir;
    // }
    // model_dir {
    //     take -->;
    // }

    root {
        spawn here --> node::flair_ner;
        take --> node::flair_ner;
    }

}

# infer
walker predict_flair{
    has text;
    #declare default labels
    has ner_labels = ["dayofweek","time", "haircut_style"];

    // root {
    //     take --> node::model_dir;
    // }
    // model_dir {
    //     take -->;
    // }
    root {
        spawn here --> node::flair_ner;
        take --> node::flair_ner;
    }

}
# creating walker for entity predictions
walker infer_zero_shot{
    has model_name;
    has model_type;
    has text;
    has labels;

    root {
        take --> node::model_dir;
    }
    model_dir {
        take -->;
    }
}