package cz.smartcontrol.licensing.web.tools;

import java.io.Writer;

/**
 *
 * @author strzinek
 */
public interface CsvProvider {
    
    void printCsv( Writer out, Object reportData ) throws Exception;
    
}
