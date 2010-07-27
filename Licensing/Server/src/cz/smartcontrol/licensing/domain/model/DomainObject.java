package cz.smartcontrol.licensing.domain.model;

import java.io.Serializable;

public interface DomainObject extends Serializable {

    public Serializable getPrimaryKey();

}
