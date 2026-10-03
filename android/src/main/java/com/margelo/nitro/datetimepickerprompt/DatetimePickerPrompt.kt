package com.margelo.nitro.datetimepickerprompt
  
import com.facebook.proguard.annotations.DoNotStrip

@DoNotStrip
class DatetimePickerPrompt : HybridDatetimePickerPromptSpec() {
  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }
}
