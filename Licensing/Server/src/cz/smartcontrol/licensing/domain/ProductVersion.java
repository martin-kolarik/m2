/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package cz.smartcontrol.licensing.domain;

import cz.smartcontrol.licensing.domain.model.VersionedDomainObject;
import java.io.Serializable;
import java.util.Date;
import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.JoinColumn;
import javax.persistence.ManyToOne;
import javax.persistence.OneToOne;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

/**
 *
 * @author Martin
 */
@Entity
@Table(name="app_version")
public class ProductVersion implements VersionedDomainObject {
    
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "version_id")
    private Long versionId;
    
    @Column(name="version_string", nullable=false)
    private String versionString;
    
    @Column(name="type", nullable=false)
    private VersionType type;
    
    @Column(name="type_sequence", nullable=false)
    private Long typeSequence;
    
    @ManyToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name="product")
    private Product product;
    
    @Column(name="starts", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date released;
    
    @Column(name="abandoned", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date abandoned;
    
    @OneToOne(cascade=CascadeType.REFRESH, fetch=FetchType.LAZY)
    @JoinColumn(name = "replaced_by", nullable = true)
    private ProductVersion replacedBy;
    
    @Column(name="supported", nullable=true)
    @Temporal(TemporalType.TIMESTAMP)
    private Date supported;
    
    @Column(name="created", nullable=false)
    @Temporal(TemporalType.TIMESTAMP)
    private Date created;
    
    @Column(name="version", nullable=false)
    @Version
    private Long version;
    
    public Serializable getPrimaryKey() {
        return getVersionId();
    }

    public Date getCreated() {
        return created;
    }

    public void setCreated( Date created ) {
        this.created = created;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion( Long version ) {
        this.version = version;
    }

    public Long getVersionId() {
        return versionId;
    }

    public void setVersionId( Long versionId ) {
        this.versionId = versionId;
    }

    public String getVersionString() {
        return versionString;
    }

    public void setVersionString( String versionString ) {
        this.versionString = versionString;
    }

    public VersionType getType() {
        return type;
    }

    public void setType( VersionType type ) {
        this.type = type;
    }

    public Long getTypeSequence() {
        return typeSequence;
    }

    public void setTypeSequence( Long typeSequence ) {
        this.typeSequence = typeSequence;
    }

    public Product getProduct() {
        return product;
    }

    public void setProduct( Product product ) {
        this.product = product;
    }

    public Date getReleased() {
        return released;
    }

    public void setReleased( Date released ) {
        this.released = released;
    }

    public Date getAbandoned() {
        return abandoned;
    }

    public void setAbandoned( Date abandoned ) {
        this.abandoned = abandoned;
    }

    public ProductVersion getReplacedBy() {
        return replacedBy;
    }

    public void setReplacedBy( ProductVersion replacedBy  ) {
        this.replacedBy = replacedBy;
    }

    public Date getSupported() {
        return supported;
    }

    public void setSupported( Date supported ) {
        this.supported = supported;
    }

}
