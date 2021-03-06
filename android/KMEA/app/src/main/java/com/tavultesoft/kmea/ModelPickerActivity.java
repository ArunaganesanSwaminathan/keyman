
package com.tavultesoft.kmea;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.AdapterView;
import android.widget.ImageView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

import com.tavultesoft.kmea.data.CloudRepository;
import com.tavultesoft.kmea.data.Dataset;
import com.tavultesoft.kmea.data.LexicalModel;
import com.tavultesoft.kmea.data.adapters.NestedAdapter;
import com.tavultesoft.kmea.util.MapCompat;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Keyman Settings --> Languages Settings --> Language Settings --> Model List
 * Gets the list of installable lexical models from Keyman cloud and allows user to download a model.
 * Displays a list of available models for a language ID.
 */
public final class ModelPickerActivity extends AppCompatActivity {

  private Context context;
  private static Toolbar toolbar = null;
  private static ListView listView = null;

  private static Dataset repo;
  private boolean didExecuteParser = false;

  private final static String TAG = "ModelPickerActivity";

  private String languageID = "";
  private String customHelpLink = "";

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    supportRequestWindowFeature(Window.FEATURE_NO_TITLE);
    context = this;
    setContentView(R.layout.activity_list_layout);

    toolbar = (Toolbar) findViewById(R.id.list_toolbar);
    setSupportActionBar(toolbar);
    getSupportActionBar().setDisplayHomeAsUpEnabled(true);
    getSupportActionBar().setDisplayShowHomeEnabled(true);
    getSupportActionBar().setDisplayShowTitleEnabled(false);
    TextView textView = (TextView) findViewById(R.id.bar_title);

    Bundle bundle = getIntent().getExtras();
    String newLanguageID = bundle.getString(KMManager.KMKey_LanguageID);
    String newCustomHelpLink = bundle.getString(KMManager.KMKey_CustomHelpLink, "");

    // Sometimes we need to re-initialize the list of models that are displayed in the ListView
    languageID = newLanguageID;
    customHelpLink = newCustomHelpLink;

    final String languageName = bundle.getString(KMManager.KMKey_LanguageName);
    textView.setText(String.format(getString(R.string.model_picker_header), languageName));

    listView = (ListView) findViewById(R.id.listView);
    listView.setFastScrollEnabled(true);
  }

  @Override
  protected void onResume() {
    super.onResume();
    if (!didExecuteParser) {
      didExecuteParser = true;
      repo = CloudRepository.shared.fetchDataset(context);

      // Initialize the dataset of installed lexical models
      listView.setAdapter(new FilteredLexicalModelAdapter(context, KeyboardPickerActivity.getInstalledDataset(context), languageID));
      listView.setOnItemClickListener(new AdapterView.OnItemClickListener() {

        @Override
        public void onItemClick(AdapterView<?> parent, View view, final int position, long id) {
          int selectedIndex = position;
          LexicalModel model = ((FilteredLexicalModelAdapter) listView.getAdapter()).getItem(position);
          Map<String, String> modelInfo = model.map;
          String packageID = modelInfo.get(KMManager.KMKey_PackageID);
          String languageID = modelInfo.get(KMManager.KMKey_LanguageID);
          String modelID = modelInfo.get(KMManager.KMKey_LexicalModelID);
          String modelName = modelInfo.get(KMManager.KMKey_LexicalModelName);
          String langName = modelInfo.get(KMManager.KMKey_LanguageName);

          // File check to see if lexical model already exists locally
          File modelCheck = new File(KMManager.getLexicalModelsDir() + packageID + File.separator + modelID + ".model.js");

          String modelKey = String.format("%s_%s_%s", packageID, languageID, modelID);
          boolean modelInstalled = KeyboardPickerActivity.containsLexicalModel(context, modelKey);
          boolean immediateRegister = false;
          Map<String, String> preInstalledModelMap = KMManager.getAssociatedLexicalModel(languageID);

          if (modelInstalled) {
            // Show Model Info
            listView.setItemChecked(position, true);
            listView.setSelection(position);

            // Start intent for selected Predictive Text Model screen
            if (!languageID.equalsIgnoreCase(modelInfo.get(KMManager.KMKey_LanguageID))) {
              Log.d(TAG, "Language ID " + languageID + " doesn't match model language ID: " +
                  modelInfo.get(KMManager.KMKey_LanguageID));
            }
            Bundle bundle = new Bundle();
            // Note: package ID of a model is different from package ID for a keyboard.
            // Language ID can be re-used
            bundle.putString(KMManager.KMKey_PackageID, packageID);
            bundle.putString(KMManager.KMKey_LanguageID, languageID);
            bundle.putString(KMManager.KMKey_LexicalModelID, modelID);
            bundle.putString(KMManager.KMKey_LexicalModelName, modelName);
            bundle.putString(KMManager.KMKey_LexicalModelVersion,
                modelInfo.get(KMManager.KMKey_LexicalModelVersion));
            bundle.putString(KMManager.KMKey_CustomHelpLink, customHelpLink);
            Intent i = new Intent(context, ModelInfoActivity.class);
            i.putExtras(bundle);
            startActivityForResult(i, 1);
          } else if (modelCheck.exists()) {
            // Handle scenario where previously installed kmp already exists so
            // we only need to add the model to the list of installed models
            // Add help link
            modelInfo.put(KMManager.KMKey_CustomHelpLink, "");
            boolean result = KMManager.addLexicalModel(context, new HashMap<>(modelInfo));
            if (result) {
              Toast.makeText(context, getString(R.string.model_install_toast), Toast.LENGTH_SHORT).show();
            }

            immediateRegister = true;
          } else {
            // Model isn't installed so prompt to download it
            Bundle args = model.buildDownloadBundle();
            Intent i = new Intent(getApplicationContext(), KMKeyboardDownloaderActivity.class);
            i.putExtras(args);
            startActivity(i);
          }

          // If we had a previously-installed lexical model, we should 'deinstall' it so that only
          // one model is actively linked to any given language.
          if(!modelInstalled) {
            // While awkward, we must obtain the preInstalledModelMap before any installations occur.
            // We don't want to remove the model we just installed, after all!
            if(preInstalledModelMap != null) {
              LexicalModel preInstalled = new LexicalModel(preInstalledModelMap);
              String itemKey = String.format("%s_%s_%s",
                  preInstalled.map.get(KMManager.KMKey_PackageID), preInstalled.getLanguageCode(), preInstalled.getResourceId());
              int modelIndex = KeyboardPickerActivity.getLexicalModelIndex(context, itemKey);
              KeyboardPickerActivity.deleteLexicalModel(context, modelIndex, true);
            }
          }

          if(immediateRegister) {
            // Register associated lexical model if it matches the active keyboard's language code;
            // it's safe since we're on the same thread.  Needs to be called AFTER deinstalling the old one.
            String kbdLgCode = KMManager.getCurrentKeyboardInfo(context).get(KMManager.KMKey_LanguageID);
            if(kbdLgCode.equals(languageID)) {
              KMManager.registerAssociatedLexicalModel(languageID);
            }
          }

          // Force a display refresh.
          ((FilteredLexicalModelAdapter) listView.getAdapter()).notifyDataSetChanged();
        }
      });

      Intent i = getIntent();
      listView.setSelectionFromTop(i.getIntExtra("listPosition", 0),
          i.getIntExtra("offsetY", 0));
    } else {
      // Forces a display refresh.
      ((FilteredLexicalModelAdapter) listView.getAdapter()).notifyDataSetChanged();
    }
  }

  @Override
  protected void onPause() {
    super.onPause();

  }

  @Override
  public boolean onSupportNavigateUp() {
    onBackPressed();
    return true;
  }

  @Override
  public void onBackPressed() {
    finish();
  }

  // Uses the repo dataset's master lexical model list to create a filtered adapter for use here.
  // As this one is specific to this class, we can implement Activity-specific functionality within it.
  static private class FilteredLexicalModelAdapter extends NestedAdapter<LexicalModel, Dataset.LexicalModels, String> {
    static final int RESOURCE = R.layout.models_list_row_layout;
    private final Context context;

    static private class ViewHolder {
      ImageView imgInstalled;
      ImageView imgDetails;
      TextView text;
    }

    public FilteredLexicalModelAdapter(@NonNull Context context, final Dataset repo, final String languageCode) {
      // Goal:  to not need a custom filter here, instead relying on LanguageDataset's built-in filters.
      super(context, RESOURCE, repo.lexicalModels, repo.lexicalModelFilter, languageCode);

      this.context = context;
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
      LexicalModel model = this.getItem(position);
      ViewHolder holder;

      // If we're being told to reuse an existing view, do that.  It's automatic optimization.
      if (convertView == null) {
        convertView = LayoutInflater.from(getContext()).inflate(RESOURCE, parent, false);
        holder = new ViewHolder();

        holder.imgInstalled = convertView.findViewById(R.id.image1);
        holder.text = convertView.findViewById(R.id.text1);
        holder.imgDetails = convertView.findViewById(R.id.image2);
        convertView.setTag(holder);
      } else {
        holder = (ViewHolder) convertView.getTag();
      }

      // Needed for the check below.
      String packageID = model.map.get(KMManager.KMKey_PackageID);
      String languageID = model.map.get(KMManager.KMKey_LanguageID);
      String modelID = model.map.get(KMManager.KMKey_LexicalModelID);
      String modelKey = String.format("%s_%s_%s", packageID, languageID, modelID);

      // TODO:  Refactor this check - we should instead test against the installed models listing
      //        once it has its own backing Dataset instance.
      // Is this an installed model or not?

      if (KeyboardPickerActivity.containsLexicalModel(context, modelKey)) {
        holder.imgInstalled.setImageResource(R.drawable.ic_check);
        holder.imgDetails.setImageResource(R.drawable.ic_arrow_forward);
      } else {
        holder.imgInstalled.setImageResource(0);
        holder.imgDetails.setImageResource(0);
      }

      holder.text.setText(model.map.get(KMManager.KMKey_LexicalModelName));

      return convertView;
    }
  }
}
