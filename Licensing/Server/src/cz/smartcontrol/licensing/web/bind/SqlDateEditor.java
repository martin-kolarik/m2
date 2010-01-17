package cz.smartcontrol.licensing.web.bind;

import java.beans.PropertyEditorSupport;
import java.sql.Date;
import java.text.DateFormat;
import java.text.ParseException;
import org.springframework.util.StringUtils;

/**
 *
 * @author pajosh
 */
class SqlDateEditor extends PropertyEditorSupport {

    private boolean isRequired = false;
    DateFormat format;

    SqlDateEditor(DateFormat format, boolean isRequired) {
        this.isRequired = isRequired;
        this.format = format;
    }

    @Override
    public void setAsText(String text) throws IllegalArgumentException {
        java.util.Date d = null;
        if (!this.isRequired && !StringUtils.hasText(text)) {
            setValue(null);
        } else {
            try {
                d = format.parse(text);
                setValue(new Date(d.getTime()));
            } catch (ParseException ex) {
                throw new IllegalArgumentException("Could not parse date: " + ex.getMessage());
            }
        }
    }

    @Override
    public String getAsText() {
        Date value = (java.sql.Date) getValue();
        if (value != null) {
            java.util.Date d = new java.util.Date(value.getTime());
            return format.format(d);

        } else {
            return "";
        }
    }
}
