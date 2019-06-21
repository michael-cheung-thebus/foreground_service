package org.thebus.foreground_service

import android.os.Build
import androidx.annotation.RequiresApi

//because dates
class DateHelper: Comparable<DateHelper>{

    override fun compareTo(other: DateHelper): Int =
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            this.internalDate_O.compareTo(other.internalDate_O)
        }
        else {
            this.internalDate.compareTo(other.internalDate)
        }

    @RequiresApi(Build.VERSION_CODES.O)
    private var internalDate_O = java.time.Instant.now()
    private var internalDate = java.util.Calendar.getInstance()

    override fun toString(): String =
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O){
            internalDate_O.toString()
        }else{
            internalDate.toString()
        }

    fun secondsUntil(otherDateHelper: DateHelper): Long =
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            this.internalDate_O.until(
                    otherDateHelper.internalDate_O,
                    java.time.temporal.ChronoUnit.SECONDS
            )
        }else{
            (
                (
                    otherDateHelper.internalDate.timeInMillis
                            -
                    this.internalDate.timeInMillis
                )
                /
                1000
            )
        }
}