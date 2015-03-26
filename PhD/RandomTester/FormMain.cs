/*
 * Copyright © 2006 Stefan Troschütz (stefan@troschuetz.de)
 * 
 * This file is part of "Troschuetz.RandomTester".
 * 
 * "Troschuetz.RandomTester" is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License or any later version.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 * 
 * FormMain.cs, 14.09.2006
 * 
 * 09.08.2006: Initial version
 * 17.08.2006: Display unit "samples/s" in generator test
 *             Use byte[64] for testing Generator.NextBytes method so the test is less time consuming
 * 14.09.2006: Adjusted distribution visualization so that the last interval of histograms is displayed correctly
 *               (Till now the histogram graphs consisted of points representing the minimum bounds of histogram intervals,
 *               so the last interval wasn't really drawn; therefor graphs now contain an additional point for the
 *               maximum bound of the last interval which of course has the same y-value as the corresponding minimum bound)
 * 
 * This program uses ZedGraph Class Library and Troschuetz.Random Class Library.
 * The libraries and its use are covered by the GNU Lesser General Public License; 
 * either version 2.1, or any later version.
 * 
 */

using System;
using System.Diagnostics;
using System.Drawing;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Reflection;
using System.Windows.Forms;
using Troschuetz.Random;
using ZedGraph;

namespace Troschuetz.RandomTester
{
    /// <summary>
    /// Summary description for FormMain.
	/// </summary>
    public class FormMain : System.Windows.Forms.Form
    {
        #region instance fields
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.Container components = null;

        /// <summary>
        /// Stores <see cref="Type"/> objects of inheritors of Distribution type.
        /// </summary>
        private SortedList<string, Type> distributions;

        /// <summary>
        /// Stores <see cref="Type"/> objects of inheritors of Generator type.
        /// </summary>
        private SortedList<string, Type> generators;

        /// <summary>
        /// Stores the currently active inheritor of Distribution type.
        /// </summary>
        private object currentDistribution;

        /// <summary>
        /// Stores the <see cref="Type"/> object for the Distribution type.
        /// </summary>
        private Type typeDistribution;

        /// <summary>
        /// Stores the <see cref="Type"/> object for the Generator type.
        /// </summary>
        private Type typeGenerator;
        private TabPage tabPageGenerators;
        private NumericUpDown numericUpDownGenSamples;
        private Label label7;
        private Button buttonTestGenerators;
        private CheckedListBox checkedListBoxGenerators;
        private Label label6;
        private Button buttonSelect;
        private Button buttonDeselect;
        private TabPage tabPageDistributions2;
        private RichTextBox richTextBoxDistributionTest;
        private NumericUpDown numericUpDownSamples2;
        private Label label17;
        private Button buttonTest2;
        private CheckedListBox checkedListBoxDistributions;
        private Label label18;
        private Button buttonSelectAll;
        private Button buttonDeselectAll;
        private TabPage tabPageDistributions1;
        private ComboBox comboBoxDistribution;
        private Label label8;
        private GroupBox groupBoxDistribution1;
        private GroupBox groupBoxDistribution2;
        private Button buttonClear;
        private Label label4;
        private Label label2;
        private Button buttonTest;
        private NumericUpDown numericUpDownSamples;
        private NumericUpDown numericUpDownSteps;
        private CheckBox checkBoxSmooth;
        private CheckBox checkBoxHistogramBounds;
        private NumericUpDown numericUpDownMinimum;
        private Label label3;
        private NumericUpDown numericUpDownMaximum;
        private Label label5;
        private RichTextBox richTextBoxTest;
        private ZedGraphControl zedGraphControlTest;
        private ComboBox comboBoxGenerator;
        private Label label1;
        private ComboBox comboBoxGenerator2;
        private Label label9;
        private DataGridView dataGridViewGenerators;
        private CheckBox checkBoxNext;
        private CheckBox checkBoxNextBoolean;
        private CheckBox checkBoxNextMinMax;
        private CheckBox checkBoxNextMax;
        private CheckBox checkBoxNextBytes;
        private CheckBox checkBoxNextDoubleMinMax;
        private CheckBox checkBoxNextDoubleMax;
        private CheckBox checkBoxNextDouble;
        private DataGridViewTextBoxColumn Generator;
        private DataGridViewTextBoxColumn Next;
        private DataGridViewTextBoxColumn NextMax;
        private DataGridViewTextBoxColumn NextMinMax;
        private DataGridViewTextBoxColumn NextDouble;
        private DataGridViewTextBoxColumn NextDoubleMax;
        private DataGridViewTextBoxColumn NextDoubleMinMax;
        private DataGridViewTextBoxColumn NextBoolean;
        private DataGridViewTextBoxColumn NextBytes;
        private DataGridViewTextBoxColumn Unit;
        private TabControl tabControl1;
        #endregion

        #region construction, destruction
        #region Windows Form Designer generated code
        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(FormMain));
            this.tabPageGenerators = new System.Windows.Forms.TabPage();
            this.checkBoxNextBytes = new System.Windows.Forms.CheckBox();
            this.checkBoxNextBoolean = new System.Windows.Forms.CheckBox();
            this.checkBoxNextDoubleMinMax = new System.Windows.Forms.CheckBox();
            this.checkBoxNextDoubleMax = new System.Windows.Forms.CheckBox();
            this.checkBoxNextMinMax = new System.Windows.Forms.CheckBox();
            this.checkBoxNextDouble = new System.Windows.Forms.CheckBox();
            this.checkBoxNextMax = new System.Windows.Forms.CheckBox();
            this.checkBoxNext = new System.Windows.Forms.CheckBox();
            this.dataGridViewGenerators = new System.Windows.Forms.DataGridView();
            this.numericUpDownGenSamples = new System.Windows.Forms.NumericUpDown();
            this.label7 = new System.Windows.Forms.Label();
            this.buttonTestGenerators = new System.Windows.Forms.Button();
            this.checkedListBoxGenerators = new System.Windows.Forms.CheckedListBox();
            this.label6 = new System.Windows.Forms.Label();
            this.buttonSelect = new System.Windows.Forms.Button();
            this.buttonDeselect = new System.Windows.Forms.Button();
            this.tabPageDistributions2 = new System.Windows.Forms.TabPage();
            this.comboBoxGenerator2 = new System.Windows.Forms.ComboBox();
            this.label9 = new System.Windows.Forms.Label();
            this.richTextBoxDistributionTest = new System.Windows.Forms.RichTextBox();
            this.numericUpDownSamples2 = new System.Windows.Forms.NumericUpDown();
            this.label17 = new System.Windows.Forms.Label();
            this.buttonTest2 = new System.Windows.Forms.Button();
            this.checkedListBoxDistributions = new System.Windows.Forms.CheckedListBox();
            this.label18 = new System.Windows.Forms.Label();
            this.buttonSelectAll = new System.Windows.Forms.Button();
            this.buttonDeselectAll = new System.Windows.Forms.Button();
            this.tabPageDistributions1 = new System.Windows.Forms.TabPage();
            this.comboBoxGenerator = new System.Windows.Forms.ComboBox();
            this.label1 = new System.Windows.Forms.Label();
            this.comboBoxDistribution = new System.Windows.Forms.ComboBox();
            this.label8 = new System.Windows.Forms.Label();
            this.groupBoxDistribution1 = new System.Windows.Forms.GroupBox();
            this.groupBoxDistribution2 = new System.Windows.Forms.GroupBox();
            this.buttonClear = new System.Windows.Forms.Button();
            this.label4 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.buttonTest = new System.Windows.Forms.Button();
            this.numericUpDownSamples = new System.Windows.Forms.NumericUpDown();
            this.numericUpDownSteps = new System.Windows.Forms.NumericUpDown();
            this.checkBoxSmooth = new System.Windows.Forms.CheckBox();
            this.checkBoxHistogramBounds = new System.Windows.Forms.CheckBox();
            this.numericUpDownMinimum = new System.Windows.Forms.NumericUpDown();
            this.label3 = new System.Windows.Forms.Label();
            this.numericUpDownMaximum = new System.Windows.Forms.NumericUpDown();
            this.label5 = new System.Windows.Forms.Label();
            this.richTextBoxTest = new System.Windows.Forms.RichTextBox();
            this.zedGraphControlTest = new ZedGraph.ZedGraphControl();
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.Generator = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Next = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextMax = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextMinMax = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextDouble = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextDoubleMax = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextDoubleMinMax = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextBoolean = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.NextBytes = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.Unit = new System.Windows.Forms.DataGridViewTextBoxColumn();
            this.tabPageGenerators.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.dataGridViewGenerators)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownGenSamples)).BeginInit();
            this.tabPageDistributions2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSamples2)).BeginInit();
            this.tabPageDistributions1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSamples)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSteps)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownMinimum)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownMaximum)).BeginInit();
            this.tabControl1.SuspendLayout();
            this.SuspendLayout();
            // 
            // tabPageGenerators
            // 
            this.tabPageGenerators.Controls.Add(this.checkBoxNextBytes);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextBoolean);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextDoubleMinMax);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextDoubleMax);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextMinMax);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextDouble);
            this.tabPageGenerators.Controls.Add(this.checkBoxNextMax);
            this.tabPageGenerators.Controls.Add(this.checkBoxNext);
            this.tabPageGenerators.Controls.Add(this.dataGridViewGenerators);
            this.tabPageGenerators.Controls.Add(this.numericUpDownGenSamples);
            this.tabPageGenerators.Controls.Add(this.label7);
            this.tabPageGenerators.Controls.Add(this.buttonTestGenerators);
            this.tabPageGenerators.Controls.Add(this.checkedListBoxGenerators);
            this.tabPageGenerators.Controls.Add(this.label6);
            this.tabPageGenerators.Controls.Add(this.buttonSelect);
            this.tabPageGenerators.Controls.Add(this.buttonDeselect);
            this.tabPageGenerators.Location = new System.Drawing.Point(4, 22);
            this.tabPageGenerators.Name = "tabPageGenerators";
            this.tabPageGenerators.Size = new System.Drawing.Size(1008, 710);
            this.tabPageGenerators.TabIndex = 1;
            this.tabPageGenerators.Text = "Generators";
            this.tabPageGenerators.UseVisualStyleBackColor = true;
            // 
            // checkBoxNextBytes
            // 
            this.checkBoxNextBytes.AutoSize = true;
            this.checkBoxNextBytes.Location = new System.Drawing.Point(640, 48);
            this.checkBoxNextBytes.Name = "checkBoxNextBytes";
            this.checkBoxNextBytes.Size = new System.Drawing.Size(118, 17);
            this.checkBoxNextBytes.TabIndex = 12;
            this.checkBoxNextBytes.Text = "NextBytes(byte[64])";
            this.checkBoxNextBytes.UseVisualStyleBackColor = true;
            this.checkBoxNextBytes.CheckedChanged += new System.EventHandler(this.checkBoxNextBytes_CheckedChanged);
            // 
            // checkBoxNextBoolean
            // 
            this.checkBoxNextBoolean.AutoSize = true;
            this.checkBoxNextBoolean.Checked = true;
            this.checkBoxNextBoolean.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBoxNextBoolean.Location = new System.Drawing.Point(640, 24);
            this.checkBoxNextBoolean.Name = "checkBoxNextBoolean";
            this.checkBoxNextBoolean.Size = new System.Drawing.Size(93, 17);
            this.checkBoxNextBoolean.TabIndex = 12;
            this.checkBoxNextBoolean.Text = "NextBoolean()";
            this.checkBoxNextBoolean.UseVisualStyleBackColor = true;
            this.checkBoxNextBoolean.CheckedChanged += new System.EventHandler(this.checkBoxNextBoolean_CheckedChanged);
            // 
            // checkBoxNextDoubleMinMax
            // 
            this.checkBoxNextDoubleMinMax.AutoSize = true;
            this.checkBoxNextDoubleMinMax.Location = new System.Drawing.Point(512, 72);
            this.checkBoxNextDoubleMinMax.Name = "checkBoxNextDoubleMinMax";
            this.checkBoxNextDoubleMinMax.Size = new System.Drawing.Size(118, 17);
            this.checkBoxNextDoubleMinMax.TabIndex = 12;
            this.checkBoxNextDoubleMinMax.Text = "NextDouble(-99,99)";
            this.checkBoxNextDoubleMinMax.UseVisualStyleBackColor = true;
            this.checkBoxNextDoubleMinMax.CheckedChanged += new System.EventHandler(this.checkBoxNextDoubleMinMax_CheckedChanged);
            // 
            // checkBoxNextDoubleMax
            // 
            this.checkBoxNextDoubleMax.AutoSize = true;
            this.checkBoxNextDoubleMax.Location = new System.Drawing.Point(512, 48);
            this.checkBoxNextDoubleMax.Name = "checkBoxNextDoubleMax";
            this.checkBoxNextDoubleMax.Size = new System.Drawing.Size(100, 17);
            this.checkBoxNextDoubleMax.TabIndex = 12;
            this.checkBoxNextDoubleMax.Text = "NextDouble(99)";
            this.checkBoxNextDoubleMax.UseVisualStyleBackColor = true;
            this.checkBoxNextDoubleMax.CheckedChanged += new System.EventHandler(this.checkBoxNextDoubleMax_CheckedChanged);
            // 
            // checkBoxNextMinMax
            // 
            this.checkBoxNextMinMax.AutoSize = true;
            this.checkBoxNextMinMax.Location = new System.Drawing.Point(408, 72);
            this.checkBoxNextMinMax.Name = "checkBoxNextMinMax";
            this.checkBoxNextMinMax.Size = new System.Drawing.Size(84, 17);
            this.checkBoxNextMinMax.TabIndex = 12;
            this.checkBoxNextMinMax.Text = "Next(-99,99)";
            this.checkBoxNextMinMax.UseVisualStyleBackColor = true;
            this.checkBoxNextMinMax.CheckedChanged += new System.EventHandler(this.checkBoxNextMinMax_CheckedChanged);
            // 
            // checkBoxNextDouble
            // 
            this.checkBoxNextDouble.AutoSize = true;
            this.checkBoxNextDouble.Checked = true;
            this.checkBoxNextDouble.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBoxNextDouble.Location = new System.Drawing.Point(512, 24);
            this.checkBoxNextDouble.Name = "checkBoxNextDouble";
            this.checkBoxNextDouble.Size = new System.Drawing.Size(88, 17);
            this.checkBoxNextDouble.TabIndex = 12;
            this.checkBoxNextDouble.Text = "NextDouble()";
            this.checkBoxNextDouble.UseVisualStyleBackColor = true;
            this.checkBoxNextDouble.CheckedChanged += new System.EventHandler(this.checkBoxNextDouble_CheckedChanged);
            // 
            // checkBoxNextMax
            // 
            this.checkBoxNextMax.AutoSize = true;
            this.checkBoxNextMax.Location = new System.Drawing.Point(408, 48);
            this.checkBoxNextMax.Name = "checkBoxNextMax";
            this.checkBoxNextMax.Size = new System.Drawing.Size(66, 17);
            this.checkBoxNextMax.TabIndex = 12;
            this.checkBoxNextMax.Text = "Next(99)";
            this.checkBoxNextMax.UseVisualStyleBackColor = true;
            this.checkBoxNextMax.CheckedChanged += new System.EventHandler(this.checkBoxNextMax_CheckedChanged);
            // 
            // checkBoxNext
            // 
            this.checkBoxNext.AutoSize = true;
            this.checkBoxNext.Checked = true;
            this.checkBoxNext.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBoxNext.Location = new System.Drawing.Point(408, 24);
            this.checkBoxNext.Name = "checkBoxNext";
            this.checkBoxNext.Size = new System.Drawing.Size(54, 17);
            this.checkBoxNext.TabIndex = 12;
            this.checkBoxNext.Text = "Next()";
            this.checkBoxNext.UseVisualStyleBackColor = true;
            this.checkBoxNext.CheckedChanged += new System.EventHandler(this.CheckBoxNext_CheckedChanged);
            // 
            // dataGridViewGenerators
            // 
            this.dataGridViewGenerators.AllowUserToAddRows = false;
            this.dataGridViewGenerators.AllowUserToDeleteRows = false;
            this.dataGridViewGenerators.AllowUserToResizeColumns = false;
            this.dataGridViewGenerators.AllowUserToResizeRows = false;
            this.dataGridViewGenerators.AutoSizeColumnsMode = System.Windows.Forms.DataGridViewAutoSizeColumnsMode.DisplayedCells;
            this.dataGridViewGenerators.AutoSizeRowsMode = System.Windows.Forms.DataGridViewAutoSizeRowsMode.DisplayedCells;
            this.dataGridViewGenerators.ColumnHeadersHeightSizeMode = System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode.AutoSize;
            this.dataGridViewGenerators.Columns.AddRange(new System.Windows.Forms.DataGridViewColumn[] {
            this.Generator,
            this.Next,
            this.NextMax,
            this.NextMinMax,
            this.NextDouble,
            this.NextDoubleMax,
            this.NextDoubleMinMax,
            this.NextBoolean,
            this.NextBytes,
            this.Unit});
            this.dataGridViewGenerators.Location = new System.Drawing.Point(208, 128);
            this.dataGridViewGenerators.Name = "dataGridViewGenerators";
            this.dataGridViewGenerators.ReadOnly = true;
            this.dataGridViewGenerators.RowHeadersWidthSizeMode = System.Windows.Forms.DataGridViewRowHeadersWidthSizeMode.AutoSizeToDisplayedHeaders;
            this.dataGridViewGenerators.ShowEditingIcon = false;
            this.dataGridViewGenerators.Size = new System.Drawing.Size(792, 576);
            this.dataGridViewGenerators.TabIndex = 11;
            // 
            // numericUpDownGenSamples
            // 
            this.numericUpDownGenSamples.Location = new System.Drawing.Point(312, 64);
            this.numericUpDownGenSamples.Maximum = new decimal(new int[] {
            100000000,
            0,
            0,
            0});
            this.numericUpDownGenSamples.Minimum = new decimal(new int[] {
            1000,
            0,
            0,
            0});
            this.numericUpDownGenSamples.Name = "numericUpDownGenSamples";
            this.numericUpDownGenSamples.Size = new System.Drawing.Size(80, 20);
            this.numericUpDownGenSamples.TabIndex = 9;
            this.numericUpDownGenSamples.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownGenSamples.Value = new decimal(new int[] {
            10000000,
            0,
            0,
            0});
            // 
            // label7
            // 
            this.label7.Location = new System.Drawing.Point(208, 64);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(112, 16);
            this.label7.TabIndex = 8;
            this.label7.Text = "Number of samples:";
            // 
            // buttonTestGenerators
            // 
            this.buttonTestGenerators.Location = new System.Drawing.Point(208, 88);
            this.buttonTestGenerators.Name = "buttonTestGenerators";
            this.buttonTestGenerators.Size = new System.Drawing.Size(184, 24);
            this.buttonTestGenerators.TabIndex = 6;
            this.buttonTestGenerators.Text = "Test selected generators";
            this.buttonTestGenerators.Click += new System.EventHandler(this.ButtonTestGenerators_Click);
            // 
            // checkedListBoxGenerators
            // 
            this.checkedListBoxGenerators.CheckOnClick = true;
            this.checkedListBoxGenerators.Location = new System.Drawing.Point(8, 24);
            this.checkedListBoxGenerators.Name = "checkedListBoxGenerators";
            this.checkedListBoxGenerators.Size = new System.Drawing.Size(184, 679);
            this.checkedListBoxGenerators.TabIndex = 5;
            // 
            // label6
            // 
            this.label6.Location = new System.Drawing.Point(8, 8);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(136, 16);
            this.label6.TabIndex = 4;
            this.label6.Text = "Select generators to test:";
            // 
            // buttonSelect
            // 
            this.buttonSelect.Location = new System.Drawing.Point(208, 24);
            this.buttonSelect.Name = "buttonSelect";
            this.buttonSelect.Size = new System.Drawing.Size(88, 24);
            this.buttonSelect.TabIndex = 6;
            this.buttonSelect.Text = "Select all";
            this.buttonSelect.Click += new System.EventHandler(this.ButtonSelect_Click);
            // 
            // buttonDeselect
            // 
            this.buttonDeselect.Location = new System.Drawing.Point(304, 24);
            this.buttonDeselect.Name = "buttonDeselect";
            this.buttonDeselect.Size = new System.Drawing.Size(88, 24);
            this.buttonDeselect.TabIndex = 6;
            this.buttonDeselect.Text = "Deselect all";
            this.buttonDeselect.Click += new System.EventHandler(this.ButtonDeselect_Click);
            // 
            // tabPageDistributions2
            // 
            this.tabPageDistributions2.Controls.Add(this.comboBoxGenerator2);
            this.tabPageDistributions2.Controls.Add(this.label9);
            this.tabPageDistributions2.Controls.Add(this.richTextBoxDistributionTest);
            this.tabPageDistributions2.Controls.Add(this.numericUpDownSamples2);
            this.tabPageDistributions2.Controls.Add(this.label17);
            this.tabPageDistributions2.Controls.Add(this.buttonTest2);
            this.tabPageDistributions2.Controls.Add(this.checkedListBoxDistributions);
            this.tabPageDistributions2.Controls.Add(this.label18);
            this.tabPageDistributions2.Controls.Add(this.buttonSelectAll);
            this.tabPageDistributions2.Controls.Add(this.buttonDeselectAll);
            this.tabPageDistributions2.Location = new System.Drawing.Point(4, 22);
            this.tabPageDistributions2.Name = "tabPageDistributions2";
            this.tabPageDistributions2.Padding = new System.Windows.Forms.Padding(3);
            this.tabPageDistributions2.Size = new System.Drawing.Size(1008, 710);
            this.tabPageDistributions2.TabIndex = 2;
            this.tabPageDistributions2.Text = "Distributions II";
            this.tabPageDistributions2.UseVisualStyleBackColor = true;
            // 
            // comboBoxGenerator2
            // 
            this.comboBoxGenerator2.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxGenerator2.Location = new System.Drawing.Point(208, 24);
            this.comboBoxGenerator2.Name = "comboBoxGenerator2";
            this.comboBoxGenerator2.Size = new System.Drawing.Size(184, 21);
            this.comboBoxGenerator2.TabIndex = 19;
            // 
            // label9
            // 
            this.label9.Location = new System.Drawing.Point(208, 8);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(168, 16);
            this.label9.TabIndex = 20;
            this.label9.Text = "Select an underlying generator :";
            // 
            // richTextBoxDistributionTest
            // 
            this.richTextBoxDistributionTest.Location = new System.Drawing.Point(208, 88);
            this.richTextBoxDistributionTest.Name = "richTextBoxDistributionTest";
            this.richTextBoxDistributionTest.ReadOnly = true;
            this.richTextBoxDistributionTest.Size = new System.Drawing.Size(792, 615);
            this.richTextBoxDistributionTest.TabIndex = 18;
            this.richTextBoxDistributionTest.Text = "";
            // 
            // numericUpDownSamples2
            // 
            this.numericUpDownSamples2.Location = new System.Drawing.Point(504, 24);
            this.numericUpDownSamples2.Maximum = new decimal(new int[] {
            10000000,
            0,
            0,
            0});
            this.numericUpDownSamples2.Minimum = new decimal(new int[] {
            1000,
            0,
            0,
            0});
            this.numericUpDownSamples2.Name = "numericUpDownSamples2";
            this.numericUpDownSamples2.Size = new System.Drawing.Size(80, 20);
            this.numericUpDownSamples2.TabIndex = 17;
            this.numericUpDownSamples2.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownSamples2.Value = new decimal(new int[] {
            1000000,
            0,
            0,
            0});
            // 
            // label17
            // 
            this.label17.Location = new System.Drawing.Point(400, 24);
            this.label17.Name = "label17";
            this.label17.Size = new System.Drawing.Size(112, 16);
            this.label17.TabIndex = 16;
            this.label17.Text = "Number of samples:";
            // 
            // buttonTest2
            // 
            this.buttonTest2.Location = new System.Drawing.Point(400, 56);
            this.buttonTest2.Name = "buttonTest2";
            this.buttonTest2.Size = new System.Drawing.Size(184, 24);
            this.buttonTest2.TabIndex = 15;
            this.buttonTest2.Text = "Test selected distributions";
            this.buttonTest2.Click += new System.EventHandler(this.buttonTest2_Click);
            // 
            // checkedListBoxDistributions
            // 
            this.checkedListBoxDistributions.CheckOnClick = true;
            this.checkedListBoxDistributions.Location = new System.Drawing.Point(8, 23);
            this.checkedListBoxDistributions.Name = "checkedListBoxDistributions";
            this.checkedListBoxDistributions.Size = new System.Drawing.Size(184, 679);
            this.checkedListBoxDistributions.TabIndex = 12;
            // 
            // label18
            // 
            this.label18.Location = new System.Drawing.Point(8, 7);
            this.label18.Name = "label18";
            this.label18.Size = new System.Drawing.Size(136, 16);
            this.label18.TabIndex = 11;
            this.label18.Text = "Select distributions to test:";
            // 
            // buttonSelectAll
            // 
            this.buttonSelectAll.Location = new System.Drawing.Point(208, 56);
            this.buttonSelectAll.Name = "buttonSelectAll";
            this.buttonSelectAll.Size = new System.Drawing.Size(88, 24);
            this.buttonSelectAll.TabIndex = 14;
            this.buttonSelectAll.Text = "Select all";
            this.buttonSelectAll.Click += new System.EventHandler(this.ButtonSelectAll_Click);
            // 
            // buttonDeselectAll
            // 
            this.buttonDeselectAll.Location = new System.Drawing.Point(304, 56);
            this.buttonDeselectAll.Name = "buttonDeselectAll";
            this.buttonDeselectAll.Size = new System.Drawing.Size(88, 24);
            this.buttonDeselectAll.TabIndex = 13;
            this.buttonDeselectAll.Text = "Deselect all";
            this.buttonDeselectAll.Click += new System.EventHandler(this.ButtonDeselectAll_Click);
            // 
            // tabPageDistributions1
            // 
            this.tabPageDistributions1.Controls.Add(this.comboBoxGenerator);
            this.tabPageDistributions1.Controls.Add(this.label1);
            this.tabPageDistributions1.Controls.Add(this.comboBoxDistribution);
            this.tabPageDistributions1.Controls.Add(this.label8);
            this.tabPageDistributions1.Controls.Add(this.groupBoxDistribution1);
            this.tabPageDistributions1.Controls.Add(this.groupBoxDistribution2);
            this.tabPageDistributions1.Controls.Add(this.buttonClear);
            this.tabPageDistributions1.Controls.Add(this.label4);
            this.tabPageDistributions1.Controls.Add(this.label2);
            this.tabPageDistributions1.Controls.Add(this.buttonTest);
            this.tabPageDistributions1.Controls.Add(this.numericUpDownSamples);
            this.tabPageDistributions1.Controls.Add(this.numericUpDownSteps);
            this.tabPageDistributions1.Controls.Add(this.checkBoxSmooth);
            this.tabPageDistributions1.Controls.Add(this.checkBoxHistogramBounds);
            this.tabPageDistributions1.Controls.Add(this.numericUpDownMinimum);
            this.tabPageDistributions1.Controls.Add(this.label3);
            this.tabPageDistributions1.Controls.Add(this.numericUpDownMaximum);
            this.tabPageDistributions1.Controls.Add(this.label5);
            this.tabPageDistributions1.Controls.Add(this.richTextBoxTest);
            this.tabPageDistributions1.Controls.Add(this.zedGraphControlTest);
            this.tabPageDistributions1.Location = new System.Drawing.Point(4, 22);
            this.tabPageDistributions1.Name = "tabPageDistributions1";
            this.tabPageDistributions1.Size = new System.Drawing.Size(1008, 710);
            this.tabPageDistributions1.TabIndex = 0;
            this.tabPageDistributions1.Text = "Distributions I";
            this.tabPageDistributions1.UseVisualStyleBackColor = true;
            // 
            // comboBoxGenerator
            // 
            this.comboBoxGenerator.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxGenerator.Location = new System.Drawing.Point(464, 8);
            this.comboBoxGenerator.Name = "comboBoxGenerator";
            this.comboBoxGenerator.Size = new System.Drawing.Size(184, 21);
            this.comboBoxGenerator.TabIndex = 11;
            // 
            // label1
            // 
            this.label1.Location = new System.Drawing.Point(304, 8);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(168, 16);
            this.label1.TabIndex = 12;
            this.label1.Text = "Select an underlying generator :";
            // 
            // comboBoxDistribution
            // 
            this.comboBoxDistribution.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxDistribution.Location = new System.Drawing.Point(112, 8);
            this.comboBoxDistribution.Name = "comboBoxDistribution";
            this.comboBoxDistribution.Size = new System.Drawing.Size(184, 21);
            this.comboBoxDistribution.TabIndex = 1;
            // 
            // label8
            // 
            this.label8.Location = new System.Drawing.Point(8, 8);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(112, 16);
            this.label8.TabIndex = 2;
            this.label8.Text = "Select a distribution:";
            // 
            // groupBoxDistribution1
            // 
            this.groupBoxDistribution1.Location = new System.Drawing.Point(8, 40);
            this.groupBoxDistribution1.Name = "groupBoxDistribution1";
            this.groupBoxDistribution1.Size = new System.Drawing.Size(200, 24);
            this.groupBoxDistribution1.TabIndex = 3;
            this.groupBoxDistribution1.TabStop = false;
            this.groupBoxDistribution1.Text = "Distribution Characteristics";
            // 
            // groupBoxDistribution2
            // 
            this.groupBoxDistribution2.Location = new System.Drawing.Point(8, 72);
            this.groupBoxDistribution2.Name = "groupBoxDistribution2";
            this.groupBoxDistribution2.Size = new System.Drawing.Size(200, 24);
            this.groupBoxDistribution2.TabIndex = 4;
            this.groupBoxDistribution2.TabStop = false;
            this.groupBoxDistribution2.Text = "Distribution Parameters";
            // 
            // buttonClear
            // 
            this.buttonClear.Location = new System.Drawing.Point(112, 504);
            this.buttonClear.Name = "buttonClear";
            this.buttonClear.Size = new System.Drawing.Size(96, 24);
            this.buttonClear.TabIndex = 6;
            this.buttonClear.Text = "Clear histogram";
            this.buttonClear.Click += new System.EventHandler(this.ButtonClear_Click);
            // 
            // label4
            // 
            this.label4.Location = new System.Drawing.Point(8, 456);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(112, 16);
            this.label4.TabIndex = 5;
            this.label4.Text = "Histogram minimum:";
            // 
            // label2
            // 
            this.label2.Location = new System.Drawing.Point(8, 392);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(96, 16);
            this.label2.TabIndex = 5;
            this.label2.Text = "Histogram steps:";
            // 
            // buttonTest
            // 
            this.buttonTest.Location = new System.Drawing.Point(8, 504);
            this.buttonTest.Name = "buttonTest";
            this.buttonTest.Size = new System.Drawing.Size(96, 24);
            this.buttonTest.TabIndex = 6;
            this.buttonTest.Text = "Test distribution";
            this.buttonTest.Click += new System.EventHandler(this.ButtonTest_Click);
            // 
            // numericUpDownSamples
            // 
            this.numericUpDownSamples.Location = new System.Drawing.Point(112, 368);
            this.numericUpDownSamples.Maximum = new decimal(new int[] {
            10000000,
            0,
            0,
            0});
            this.numericUpDownSamples.Minimum = new decimal(new int[] {
            1000,
            0,
            0,
            0});
            this.numericUpDownSamples.Name = "numericUpDownSamples";
            this.numericUpDownSamples.Size = new System.Drawing.Size(96, 20);
            this.numericUpDownSamples.TabIndex = 7;
            this.numericUpDownSamples.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownSamples.Value = new decimal(new int[] {
            1000000,
            0,
            0,
            0});
            // 
            // numericUpDownSteps
            // 
            this.numericUpDownSteps.Location = new System.Drawing.Point(112, 392);
            this.numericUpDownSteps.Maximum = new decimal(new int[] {
            10000,
            0,
            0,
            0});
            this.numericUpDownSteps.Minimum = new decimal(new int[] {
            1,
            0,
            0,
            0});
            this.numericUpDownSteps.Name = "numericUpDownSteps";
            this.numericUpDownSteps.Size = new System.Drawing.Size(96, 20);
            this.numericUpDownSteps.TabIndex = 7;
            this.numericUpDownSteps.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownSteps.Value = new decimal(new int[] {
            100,
            0,
            0,
            0});
            // 
            // checkBoxSmooth
            // 
            this.checkBoxSmooth.Checked = true;
            this.checkBoxSmooth.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBoxSmooth.Location = new System.Drawing.Point(8, 416);
            this.checkBoxSmooth.Name = "checkBoxSmooth";
            this.checkBoxSmooth.Size = new System.Drawing.Size(200, 16);
            this.checkBoxSmooth.TabIndex = 10;
            this.checkBoxSmooth.Text = "Smooth histogram curves";
            this.checkBoxSmooth.CheckedChanged += new System.EventHandler(this.CheckBoxSmooth_CheckedChanged);
            // 
            // checkBoxHistogramBounds
            // 
            this.checkBoxHistogramBounds.Location = new System.Drawing.Point(8, 432);
            this.checkBoxHistogramBounds.Name = "checkBoxHistogramBounds";
            this.checkBoxHistogramBounds.Size = new System.Drawing.Size(200, 16);
            this.checkBoxHistogramBounds.TabIndex = 9;
            this.checkBoxHistogramBounds.Text = "Specify fixed histogram bounds";
            this.checkBoxHistogramBounds.CheckedChanged += new System.EventHandler(this.CheckBoxHistogramBounds_CheckedChanged);
            // 
            // numericUpDownMinimum
            // 
            this.numericUpDownMinimum.Enabled = false;
            this.numericUpDownMinimum.Location = new System.Drawing.Point(120, 456);
            this.numericUpDownMinimum.Maximum = new decimal(new int[] {
            -1,
            -1,
            -1,
            0});
            this.numericUpDownMinimum.Minimum = new decimal(new int[] {
            -1,
            -1,
            -1,
            -2147483648});
            this.numericUpDownMinimum.Name = "numericUpDownMinimum";
            this.numericUpDownMinimum.Size = new System.Drawing.Size(88, 20);
            this.numericUpDownMinimum.TabIndex = 7;
            this.numericUpDownMinimum.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownMinimum.Value = new decimal(new int[] {
            50,
            0,
            0,
            -2147483648});
            this.numericUpDownMinimum.ValueChanged += new System.EventHandler(this.NumericUpDownMinimum_ValueChanged);
            this.numericUpDownMinimum.Validated += new System.EventHandler(this.NumericUpDownMinimum_Validated);
            // 
            // label3
            // 
            this.label3.Location = new System.Drawing.Point(8, 368);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(112, 16);
            this.label3.TabIndex = 5;
            this.label3.Text = "Number of samples:";
            // 
            // numericUpDownMaximum
            // 
            this.numericUpDownMaximum.Enabled = false;
            this.numericUpDownMaximum.Location = new System.Drawing.Point(120, 480);
            this.numericUpDownMaximum.Maximum = new decimal(new int[] {
            -1,
            -1,
            -1,
            0});
            this.numericUpDownMaximum.Minimum = new decimal(new int[] {
            -1,
            -1,
            -1,
            -2147483648});
            this.numericUpDownMaximum.Name = "numericUpDownMaximum";
            this.numericUpDownMaximum.Size = new System.Drawing.Size(88, 20);
            this.numericUpDownMaximum.TabIndex = 7;
            this.numericUpDownMaximum.TextAlign = System.Windows.Forms.HorizontalAlignment.Right;
            this.numericUpDownMaximum.Value = new decimal(new int[] {
            50,
            0,
            0,
            0});
            this.numericUpDownMaximum.ValueChanged += new System.EventHandler(this.NumericUpDownMaximum_ValueChanged);
            this.numericUpDownMaximum.Validated += new System.EventHandler(this.NumericUpDownMaximum_Validated);
            // 
            // label5
            // 
            this.label5.Location = new System.Drawing.Point(8, 480);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(112, 16);
            this.label5.TabIndex = 5;
            this.label5.Text = "Histogram maximum:";
            // 
            // richTextBoxTest
            // 
            this.richTextBoxTest.Location = new System.Drawing.Point(8, 536);
            this.richTextBoxTest.Name = "richTextBoxTest";
            this.richTextBoxTest.ReadOnly = true;
            this.richTextBoxTest.Size = new System.Drawing.Size(200, 168);
            this.richTextBoxTest.TabIndex = 8;
            this.richTextBoxTest.Text = "";
            // 
            // zedGraphControlTest
            // 
            this.zedGraphControlTest.IsEnableHPan = true;
            this.zedGraphControlTest.IsEnableVPan = true;
            this.zedGraphControlTest.IsEnableZoom = false;
            this.zedGraphControlTest.IsScrollY2 = false;
            this.zedGraphControlTest.IsShowContextMenu = true;
            this.zedGraphControlTest.IsShowHScrollBar = false;
            this.zedGraphControlTest.IsShowPointValues = false;
            this.zedGraphControlTest.IsShowVScrollBar = false;
            this.zedGraphControlTest.IsZoomOnMouseCenter = false;
            this.zedGraphControlTest.Location = new System.Drawing.Point(216, 40);
            this.zedGraphControlTest.Name = "zedGraphControlTest";
            this.zedGraphControlTest.PanButtons = System.Windows.Forms.MouseButtons.Left;
            this.zedGraphControlTest.PanButtons2 = System.Windows.Forms.MouseButtons.Middle;
            this.zedGraphControlTest.PanModifierKeys2 = System.Windows.Forms.Keys.None;
            this.zedGraphControlTest.PointDateFormat = "g";
            this.zedGraphControlTest.PointValueFormat = "G";
            this.zedGraphControlTest.ScrollMaxX = 0;
            this.zedGraphControlTest.ScrollMaxY = 0;
            this.zedGraphControlTest.ScrollMaxY2 = 0;
            this.zedGraphControlTest.ScrollMinX = 0;
            this.zedGraphControlTest.ScrollMinY = 0;
            this.zedGraphControlTest.ScrollMinY2 = 0;
            this.zedGraphControlTest.Size = new System.Drawing.Size(784, 664);
            this.zedGraphControlTest.TabIndex = 0;
            this.zedGraphControlTest.ZoomButtons = System.Windows.Forms.MouseButtons.Left;
            this.zedGraphControlTest.ZoomButtons2 = System.Windows.Forms.MouseButtons.None;
            this.zedGraphControlTest.ZoomModifierKeys = System.Windows.Forms.Keys.None;
            this.zedGraphControlTest.ZoomModifierKeys2 = System.Windows.Forms.Keys.None;
            this.zedGraphControlTest.ZoomStepFraction = 0.1;
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabPageDistributions1);
            this.tabControl1.Controls.Add(this.tabPageDistributions2);
            this.tabControl1.Controls.Add(this.tabPageGenerators);
            this.tabControl1.Location = new System.Drawing.Point(0, 0);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(1016, 736);
            this.tabControl1.TabIndex = 11;
            // 
            // Generator
            // 
            this.Generator.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.Generator.Frozen = true;
            this.Generator.HeaderText = "Generator";
            this.Generator.Name = "Generator";
            this.Generator.ReadOnly = true;
            this.Generator.Width = 79;
            // 
            // Next
            // 
            this.Next.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.Next.HeaderText = "Next()";
            this.Next.Name = "Next";
            this.Next.ReadOnly = true;
            this.Next.Width = 60;
            // 
            // NextMax
            // 
            this.NextMax.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextMax.HeaderText = "Next(99)";
            this.NextMax.Name = "NextMax";
            this.NextMax.ReadOnly = true;
            this.NextMax.Visible = false;
            this.NextMax.Width = 72;
            // 
            // NextMinMax
            // 
            this.NextMinMax.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextMinMax.HeaderText = "Next(-99,99)";
            this.NextMinMax.Name = "NextMinMax";
            this.NextMinMax.ReadOnly = true;
            this.NextMinMax.Visible = false;
            this.NextMinMax.Width = 90;
            // 
            // NextDouble
            // 
            this.NextDouble.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextDouble.HeaderText = "NextDouble()";
            this.NextDouble.Name = "NextDouble";
            this.NextDouble.ReadOnly = true;
            this.NextDouble.Width = 94;
            // 
            // NextDoubleMax
            // 
            this.NextDoubleMax.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextDoubleMax.HeaderText = "NextDouble(99)";
            this.NextDoubleMax.Name = "NextDoubleMax";
            this.NextDoubleMax.ReadOnly = true;
            this.NextDoubleMax.Visible = false;
            this.NextDoubleMax.Width = 106;
            // 
            // NextDoubleMinMax
            // 
            this.NextDoubleMinMax.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextDoubleMinMax.HeaderText = "NextDouble(-99,99)";
            this.NextDoubleMinMax.Name = "NextDoubleMinMax";
            this.NextDoubleMinMax.ReadOnly = true;
            this.NextDoubleMinMax.Visible = false;
            this.NextDoubleMinMax.Width = 124;
            // 
            // NextBoolean
            // 
            this.NextBoolean.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextBoolean.HeaderText = "NextBoolean";
            this.NextBoolean.Name = "NextBoolean";
            this.NextBoolean.ReadOnly = true;
            this.NextBoolean.Width = 93;
            // 
            // NextBytes
            // 
            this.NextBytes.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.NextBytes.HeaderText = "NextBytes(byte[64])";
            this.NextBytes.Name = "NextBytes";
            this.NextBytes.ReadOnly = true;
            this.NextBytes.Visible = false;
            this.NextBytes.Width = 124;
            // 
            // Unit
            // 
            this.Unit.AutoSizeMode = System.Windows.Forms.DataGridViewAutoSizeColumnMode.DisplayedCells;
            this.Unit.HeaderText = "";
            this.Unit.Name = "Unit";
            this.Unit.ReadOnly = true;
            this.Unit.Width = 19;
            // 
            // FormMain
            // 
            this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
            this.ClientSize = new System.Drawing.Size(1018, 736);
            this.Controls.Add(this.tabControl1);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Name = "FormMain";
            this.Text = "Random Tester";
            this.tabPageGenerators.ResumeLayout(false);
            this.tabPageGenerators.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.dataGridViewGenerators)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownGenSamples)).EndInit();
            this.tabPageDistributions2.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSamples2)).EndInit();
            this.tabPageDistributions1.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSamples)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownSteps)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownMinimum)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numericUpDownMaximum)).EndInit();
            this.tabControl1.ResumeLayout(false);
            this.ResumeLayout(false);

        }
        #endregion

        /// <summary>
        /// Initializes a new instance of the <see cref="FormMain"/> class.
        /// </summary>
        public FormMain()
        {
            //
            // Required for Windows Form Designer support
            //
            InitializeComponent();

            this.zedGraphControlTest.GraphPane.Title = "";
            this.zedGraphControlTest.GraphPane.XAxis.Title = "X";
            this.zedGraphControlTest.GraphPane.YAxis.Title = "";
            this.zedGraphControlTest.GraphPane.YAxis.IsScaleVisible = false;
                
            this.LoadTroschuetzRandom();
        }

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (components != null)
                    components.Dispose();
            }
            base.Dispose(disposing);
        }
        #endregion

        #region class methods
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.Run(new FormMain());
        }
        #endregion

        #region instance methods
        /// <summary>
        /// Loads the available random distributions and generators.
        /// </summary>
        private void LoadTroschuetzRandom()
        {
            try
            {
                // Load the assembly and get the defined types.
                Assembly assembly = Assembly.LoadFrom("Troschuetz.Random.dll");
                Type[] types = assembly.GetTypes();

                this.distributions = new SortedList<string, Type>(types.Length);
                this.generators = new SortedList<string, Type>(types.Length);
                for (int index = 0; index < types.Length; index++)
                {
                    if (types[index].FullName == "Troschuetz.Random.Distribution")
                    {
                        this.typeDistribution = types[index];
                    }
                    else if (types[index].FullName == "Troschuetz.Random.Generator")
                    {
                        this.typeGenerator = types[index];
                    }
                    else if (types[index].IsSubclassOf(typeof(Distribution)))
                    {// The type inherits from Distribution type.
                        this.distributions.Add(types[index].Name, types[index]);
                    }
                    else if (types[index].IsSubclassOf(typeof(Generator)))
                    {// The type inherits from Generator type.
                        this.generators.Add(types[index].Name, types[index]);
                    }
                }
                this.distributions.TrimExcess();
                this.generators.TrimExcess();

                for (int index = 0; index < this.distributions.Count; index++)
                {
                    this.checkedListBoxDistributions.Items.Add(this.distributions.Values[index].Name);
                    this.comboBoxDistribution.Items.Add(this.distributions.Values[index].Name);
                }
                for (int index = 0; index < this.generators.Count; index++)
                {
                    this.checkedListBoxGenerators.Items.Add(this.generators.Values[index].Name);
                    this.comboBoxGenerator.Items.Add(this.generators.Values[index].Name);
                    this.comboBoxGenerator2.Items.Add(this.generators.Values[index].Name);
                }

                this.InitializeGroupBoxDistribution1();

                this.comboBoxGenerator.Items.Insert(0, "Distribution default");
                this.comboBoxGenerator.SelectedIndex = 0;
                this.comboBoxGenerator.SelectedValueChanged += new EventHandler(this.ComboBoxGenerator_SelectedValueChanged);
                this.comboBoxGenerator2.Items.Insert(0, "Distribution default");
                this.comboBoxGenerator2.SelectedIndex = 0;
                
                this.comboBoxDistribution.SelectedValueChanged += new EventHandler(this.ComboBoxDistribution_SelectedValueChanged);
                this.comboBoxDistribution.SelectedItem = this.distributions.Keys[0];
            }
            catch (Exception)
            {
                this.distributions = null;
                this.typeDistribution = null;

                this.comboBoxDistribution.Items.Clear();
                this.comboBoxDistribution.Text = "Error on loading distributions";
                this.checkedListBoxGenerators.Items.Clear();
                this.checkedListBoxGenerators.Items.Add("Error on loading distributions");

                this.generators = null;
                this.typeGenerator = null;

                this.comboBoxGenerator.Items.Clear();
                this.comboBoxGenerator.Text = "Error on loading generators";
                this.comboBoxGenerator2.Items.Clear();
                this.comboBoxGenerator2.Text = "Error on loading generators";
                this.checkedListBoxGenerators.Items.Clear();
                this.checkedListBoxGenerators.Items.Add("Error on loading generators");

                this.tabControl1.Enabled = false;
            }
        }

        #region methods regarding tabpage "Distributions I"
        /// <summary>
        /// Tests the currently selected inheritor of the Distribution type.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonTest_Click(object sender, EventArgs e)
        {
            //Adjust GUI.
            this.comboBoxDistribution.Enabled = false;
            this.comboBoxGenerator.Enabled = false;
            this.groupBoxDistribution2.Enabled = false;
            this.numericUpDownSamples.Enabled = false;
            this.numericUpDownSteps.Enabled = false;
            this.checkBoxHistogramBounds.Enabled = false;
            this.numericUpDownMinimum.Enabled = false;
            this.numericUpDownMaximum.Enabled = false;
            this.checkBoxSmooth.Enabled = false;
            this.buttonTest.Enabled = false;
            this.buttonClear.Enabled = false;
            this.richTextBoxTest.Clear();
            this.zedGraphControlTest.Invalidate();
            this.Update();

            //Generate the samples.
            Distribution distribution = (Distribution)this.currentDistribution;
            double[] samples = new double[(int)this.numericUpDownSamples.Value];
            Stopwatch watch = new Stopwatch();
            watch.Start();
            for (int index = 0; index < samples.Length; index++)
            {
                samples[index] = distribution.NextDouble();
            }
            watch.Stop();
            double duration = (double)watch.ElapsedTicks / (double)Stopwatch.Frequency;

            //Determine sum, minimum, maximum and display the last two together with a computed mean value.
            double sum = 0, minimum = double.MaxValue, maximum = double.MinValue;
            for (int index = 0; index < samples.Length; index++)
            {
                sum += samples[index];
                if (samples[index] > maximum)
                    maximum = samples[index];
                if (samples[index] < minimum)
                    minimum = samples[index];
            }
            double mean = sum / samples.Length;
            double variance = 0.0;
            for (int index = 0; index < samples.Length; index++)
            {
                variance += Math.Pow(samples[index] - mean, 2);
            }
            variance /= samples.Length;

            this.richTextBoxTest.AppendText("Time elapsed for creating " + samples.Length + " samples:\n" +
                duration.ToString("#0.0000") + " s\n\n");
            this.richTextBoxTest.AppendText("Minimum: " + this.FormatDouble(minimum) + "\n\n");
            this.richTextBoxTest.AppendText("Maximum: " + this.FormatDouble(maximum) + "\n\n");
            this.richTextBoxTest.AppendText("Mean: " + this.FormatDouble(mean) + "\n\n");
            this.richTextBoxTest.AppendText("Variance: " + this.FormatDouble(variance));

            //If the user wants to apply its own histogram bounds, assign them.
            if (this.checkBoxHistogramBounds.Checked)
            {
                minimum = (double)this.numericUpDownMinimum.Value;
                maximum = (double)this.numericUpDownMaximum.Value;
            }

            //Compute the range of histogram and generate the histogram values.
            double range = maximum - minimum;
            double[] x, y;
            if (range == 0) // cannot occur in case of user defined histogram bounds
            {
                //Samples are all the same, so use a fixed histogram.
                x = new double[] { minimum, minimum + double.Epsilon };
                y = new double[] { samples.Length, 0 };
            }
            else
            {
                x = new double[(int)this.numericUpDownSteps.Value + 1];
                y = new double[(int)this.numericUpDownSteps.Value + 1];

                // Compute the histogram intervals (minimum bound of each interval is the x-value of graph points).
                // The last graph point represents the maximum bound of the last histogram interval.
                for (int index = 0; index < x.Length - 1; index++)
                {
                    x[index] = minimum + range / (double)this.numericUpDownSteps.Value * index;
                }
                x[x.Length - 1] = maximum;

                // Iterate over samples and increase the histogram interval they lie inside.
                int samplesUsed = (int) this.numericUpDownSamples.Value;
                for (int index = 0; index < samples.Length; index++)
                {
                    if (samples[index] < minimum || samples[index] > maximum)
                    {// If user specified own histogram bounds, ignore samples that lie outside.
                        samplesUsed--;
                    }
                    else if (samples[index] == maximum)
                    {// Maximum is part of last histogram interval
                        y[y.Length - 2]++;
                    }
                    else
                    {
                        y[(int)Math.Floor((samples[index] - minimum) / range * (double)this.numericUpDownSteps.Value)]++;
                    }
                }

                // Relate the number of samples inside each histogram interval to the overall number of samples
                for (int index = 0; index < y.Length - 1; index++)
                {
                    y[index] = y[index] / samplesUsed * (double)this.numericUpDownSteps.Value;
                }

                // Assign the y-value of the last but one graph point to the last one, so that the minimum and
                //   maximum bound of the last histogram interval share the same y-value
                y[y.Length - 1] = y[y.Length - 2];
            }

            // Add the test result to the graph.
            string label = this.currentDistribution.GetType().Name;
            for (int index = 0; index < this.groupBoxDistribution2.Controls.Count; index++)
            {
                if (this.groupBoxDistribution2.Controls[index] is NumericUpDown)
                {
                    label += ("  " + ((NumericUpDown)this.groupBoxDistribution2.Controls[index]).Value.ToString("0.00"));
                }
            }
            int curves = 1 + this.zedGraphControlTest.GraphPane.CurveList.Count;
            Color color;
            if (curves > 12)
                color = Color.Black;
            else if (curves % 3 == 1)
                color = Color.FromArgb(255 - curves * 10, 0, 0);
            else if (curves % 3 == 2)
                color = Color.FromArgb(0, 255 - curves * 10, 0);
            else if (curves % 3 == 0)
                color = Color.FromArgb(0, 0, 255 - curves * 10);
            else
                color = Color.Black;
            LineItem lineItem = this.zedGraphControlTest.GraphPane.AddCurve(label, x, y, color, SymbolType.None);
            lineItem.Line.StepType = StepType.ForwardStep;
            lineItem.Line.IsSmooth = this.checkBoxSmooth.Checked;
            lineItem.Line.SmoothTension = 1.0F;
            this.zedGraphControlTest.GraphPane.AxisChange(this.CreateGraphics());
            this.zedGraphControlTest.Invalidate();

            //Adjust GUI.
            this.comboBoxDistribution.Enabled = true;
            this.comboBoxGenerator.Enabled = true;
            this.groupBoxDistribution2.Enabled = true;
            this.numericUpDownSamples.Enabled = true;
            this.numericUpDownSteps.Enabled = true;
            this.checkBoxHistogramBounds.Enabled = true;
            this.numericUpDownMinimum.Enabled = this.checkBoxHistogramBounds.Checked;
            this.numericUpDownMaximum.Enabled = this.checkBoxHistogramBounds.Checked;
            this.checkBoxSmooth.Enabled = true;
            this.buttonTest.Enabled = true;
            this.buttonClear.Enabled = true;
        }

        /// <summary>
        /// Create labels to display the values of all properties of Distribution type that are of type 
        ///   <see cref="double"/> or array of <see cref="double"/>.
        /// </summary>
        private void InitializeGroupBoxDistribution1()
        {
            PropertyInfo[] propertyInfos = this.typeDistribution.GetProperties();
            PropertyInfo propertyInfo;
            Label label;
            int count = 0;
            for (int index = 0; index < propertyInfos.Length; index++)
            {
                propertyInfo = propertyInfos[index];
                if ((propertyInfo.PropertyType == typeof(double) || propertyInfo.PropertyType == typeof(double[])) &&
                    propertyInfo.CanRead)
                {
                    label = new Label();
                    label.Location = new Point(8, 24 + count * 24);
                    label.Size = new Size(80, 16);
                    label.Text = propertyInfo.Name + ":";
                    this.groupBoxDistribution1.Controls.Add(label);

                    label = new Label();
                    label.Location = new Point(96, 24 + count * 24);
                    label.Name = propertyInfo.Name;
                    label.Size = new Size(80, 16);
                    this.groupBoxDistribution1.Controls.Add(label);

                    count++;
                }
            }
            this.groupBoxDistribution1.Size = new Size(this.groupBoxDistribution1.Size.Width,
                this.groupBoxDistribution1.Size.Height + count * 24);
            this.groupBoxDistribution2.Location = new Point(this.groupBoxDistribution2.Location.X,
                this.groupBoxDistribution2.Location.Y + count * 24);
        }

        /// <summary>
        /// Updates the displayed values of Distribution properties of the currently selected inheritor of 
        ///   Distribution type.
        /// </summary>
        private void UpdateGroupBoxDistribution1()
        {
            PropertyInfo propertyInfo;
            Label label;
            for (int index = 0; index < this.groupBoxDistribution1.Controls.Count; index++)
            {
                label = (Label)this.groupBoxDistribution1.Controls[index];
                if (label.Name == "")
                    continue;

                propertyInfo = this.currentDistribution.GetType().GetProperty(label.Name);
                if (propertyInfo.PropertyType == typeof(double))
                {
                    label.Text = this.FormatDouble((double)propertyInfo.GetValue(this.currentDistribution, null));
                }
                else if (propertyInfo.PropertyType == typeof(double[]))
                {
                    double[] values = (double[])propertyInfo.GetValue(this.currentDistribution, null);
                    label.Text = "";
                    for (int index2 = 0; index2 < values.Length; index2++)
                    {
                        label.Text += this.FormatDouble(values[index2]);
                        if (index2 < values.Length - 1)
                            label.Text += " | ";
                    }
                }
            }
        }

        /// <summary>
        /// Create <see cref="NumericUpDown"/> controls for all properties of the currently selected inheritor of 
        ///   Distribution type that are of type <see cref="double"/> or <see cref="int"/> and not defined by the 
        ///   Distribution type.
        /// </summary>
        private void UpdateGroupBoxDistribution2()
        {
            this.groupBoxDistribution2.Controls.Clear();

            PropertyInfo[] propertyInfos = this.currentDistribution.GetType().GetProperties(
                BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly);
            int count = 0;
            PropertyInfo propertyInfo;
            Label label;
            NumericUpDown num;
            for (int index = 0; index < propertyInfos.Length; index++)
            {
                propertyInfo = propertyInfos[index];
                if ((propertyInfo.PropertyType == typeof(double) || propertyInfo.PropertyType == typeof(int)) &&
                    propertyInfo.CanRead && propertyInfo.CanWrite)
                {
                    label = new Label();
                    label.Location = new Point(8, 24 + count * 24);
                    label.Size = new Size(80, 16);
                    label.Text = propertyInfo.Name + ":";
                    this.groupBoxDistribution2.Controls.Add(label);

                    num = new NumericUpDown();
                    if (propertyInfo.PropertyType == typeof(double))
                        num.DecimalPlaces = 2;
                    num.Increment = new decimal(Math.Pow(10, -1 * num.DecimalPlaces));
                    num.Location = new Point(96, 24 + count * 24);
                    if (propertyInfo.PropertyType == typeof(double))
                    {
                        num.Minimum = decimal.MinValue;
                        num.Maximum = decimal.MaxValue;
                    }
                    else
                    {
                        num.Minimum = new decimal(int.MinValue);
                        num.Maximum = new decimal(int.MaxValue);
                    }
                    num.Name = propertyInfo.Name;
                    num.Size = new Size(96, 16);
                    num.TextAlign = HorizontalAlignment.Right;
                    num.CausesValidation = true;
                    if (propertyInfo.PropertyType == typeof(double))
                        num.Value = new decimal((double)propertyInfo.GetValue(this.currentDistribution, null));
                    else
                        num.Value = new decimal((int)propertyInfo.GetValue(this.currentDistribution, null));
                    if (propertyInfo.PropertyType == typeof(double))
                    {
                        num.Validated += new EventHandler(this.Double_Validated);
                        num.ValueChanged += new EventHandler(this.Double_ValueChanged);
                    }
                    else
                    {
                        num.Validated += new EventHandler(this.Int_Validated);
                        num.ValueChanged += new EventHandler(this.Int_ValueChanged);
                    }
                    this.groupBoxDistribution2.Controls.Add(num);

                    count++;
                }
            }
            this.groupBoxDistribution2.Size = new Size(this.groupBoxDistribution2.Size.Width, 32 + count * 24);
        }

        /// <summary>
        /// Selects an inheritor of Distribution type.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ComboBoxDistribution_SelectedValueChanged(object sender, EventArgs e)
        {
            if (this.distributions[this.comboBoxDistribution.Text].GetConstructor(new Type[] { this.typeGenerator }) != null)
            {
                this.comboBoxGenerator.Enabled = true;
                if (this.comboBoxGenerator.SelectedIndex == 0)
                {
                    this.currentDistribution = Activator.CreateInstance(this.distributions[this.comboBoxDistribution.Text]);
                }
                else
                {
                    this.currentDistribution = Activator.CreateInstance(this.distributions[this.comboBoxDistribution.Text],
                        new object[] { Activator.CreateInstance(this.generators[this.comboBoxGenerator.Text]) });
                }
            }
            else
            {
                this.comboBoxGenerator.Enabled = false;
                this.currentDistribution = Activator.CreateInstance(this.distributions[this.comboBoxDistribution.Text]);
            }
            this.UpdateGroupBoxDistribution1();
            this.UpdateGroupBoxDistribution2();
        }

        /// <summary>
        /// Selects an inheritor of Generator type as underlying random number generator for current
        ///   inheritor of Distribution type.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ComboBoxGenerator_SelectedValueChanged(object sender, EventArgs e)
        {
            object newDistribution;
            if (this.comboBoxGenerator.SelectedIndex == 0)
            {
                newDistribution = Activator.CreateInstance(this.distributions[this.comboBoxDistribution.Text]);
            }
            else
            {
                newDistribution = Activator.CreateInstance(this.distributions[this.comboBoxDistribution.Text],
                    new object[] { Activator.CreateInstance(this.generators[this.comboBoxGenerator.Text]) });
            }
            PropertyInfo[] propertyInfos = this.currentDistribution.GetType().GetProperties();
            PropertyInfo propertyInfo;
            for (int index = 0; index < propertyInfos.Length; index++)
            {
                propertyInfo = propertyInfos[index];
                if (propertyInfo.CanRead && propertyInfo.CanWrite)
                {
                    propertyInfo.SetValue(newDistribution, propertyInfo.GetValue(this.currentDistribution, null), null);
                }
            }
            this.currentDistribution = newDistribution;
            this.UpdateGroupBoxDistribution1();
            this.UpdateGroupBoxDistribution2();
        }

        /// <summary>
        /// Assigns a new value to a property of the currently selected inheritor of the Distribution type that 
        ///   is of type int and updates the displayed values of its Distribution properties.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void Int_Validated(object sender, EventArgs e)
        {
            this.Int_ValueChanged(sender, e);
        }

        /// <summary>
        /// Assigns a new value to a property of the currently selected inheritor of the Distribution type that 
        ///   is of type int and updates the displayed values of its Distribution properties.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void Int_ValueChanged(object sender, EventArgs e)
        {
            NumericUpDown num = (NumericUpDown)sender;
            PropertyInfo propertyInfo = this.currentDistribution.GetType().GetProperty(num.Name);
            MethodInfo methodInfo = this.currentDistribution.GetType().GetMethod("IsValid" + num.Name);

            if (methodInfo == null || (bool)methodInfo.Invoke(this.currentDistribution, new object[] { (int)num.Value }))
            {// Either there is no method that checks for validity or the new value is valid.
                // Assign the new value to the distribution and update the GroupBox with base class infos.
                propertyInfo.SetValue(this.currentDistribution, (int)num.Value, null);
                this.UpdateGroupBoxDistribution1();
            }
            else
            {// The new value isn't valid.
                // Reassign the current value of the distribution to the NumericUpDown control.
                num.Value = new decimal((int)propertyInfo.GetValue(this.currentDistribution, null));
            }
        }

        /// <summary>
        /// Assigns a new value to a property of the currently selected inheritor of the Distribution type that 
        ///   is of type double and updates the displayed values of its Distribution properties.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void Double_Validated(object sender, EventArgs e)
        {
            this.Double_ValueChanged(sender, e);
        }

        /// <summary>
        /// Assigns a new value to a property of the currently selected inheritor of the Distribution type that 
        ///   is of type double and updates the displayed values of its Distribution properties.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void Double_ValueChanged(object sender, EventArgs e)
        {
            NumericUpDown num = (NumericUpDown)sender;
            PropertyInfo propertyInfo = this.currentDistribution.GetType().GetProperty(num.Name);
            MethodInfo methodInfo = this.currentDistribution.GetType().GetMethod("IsValid" + num.Name);

            if (methodInfo == null || (bool)methodInfo.Invoke(this.currentDistribution, new object[] { (double)num.Value }))
            {// Either there is no method that checks for validity or the new value is valid.
                // Assign the new value to the distribution and update the GroupBox with base class infos.
                propertyInfo.SetValue(this.currentDistribution, (double)num.Value, null);
                this.UpdateGroupBoxDistribution1();
            }
            else
            {// The new value isn't valid.
                // Reassign the current value of the distribution to the NumericUpDown control.
                num.Value = new decimal((double)propertyInfo.GetValue(this.currentDistribution, null));
            }
        }

        /// <summary>
        /// User wants to enable or disable specific histogram bounds.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void CheckBoxHistogramBounds_CheckedChanged(object sender, EventArgs e)
        {
            this.numericUpDownMinimum.Enabled = this.checkBoxHistogramBounds.Checked;
            this.numericUpDownMaximum.Enabled = this.checkBoxHistogramBounds.Checked;
        }

        /// <summary>
        /// Checks whether the specified value of <see cref="numericUpDownMinimum"/> is smaller than the one of
        ///   <see cref="numericUpDownMaximum"/> and corrects it, if necessary.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void NumericUpDownMinimum_Validated(object sender, EventArgs e)
        {
            this.NumericUpDownMinimum_ValueChanged(sender, e);
        }

        /// <summary>
        /// Checks whether the specified value of <see cref="numericUpDownMinimum"/> is smaller than the one of
        ///   <see cref="numericUpDownMaximum"/> and corrects it, if necessary.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void NumericUpDownMinimum_ValueChanged(object sender, EventArgs e)
        {
            if (this.numericUpDownMinimum.Value >= this.numericUpDownMaximum.Value)
                this.numericUpDownMinimum.Value = this.numericUpDownMaximum.Value - decimal.One;
        }

        /// <summary>
        /// Checks whether the specified value of <see cref="numericUpDownMaximum"/> is greater than the one of
        ///   <see cref="numericUpDownMinimum"/> and corrects it, if necessary.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void NumericUpDownMaximum_Validated(object sender, EventArgs e)
        {
            this.NumericUpDownMaximum_ValueChanged(sender, e);
        }

        /// <summary>
        /// Checks whether the specified value of <see cref="numericUpDownMaximum"/> is greater than the one of
        ///   <see cref="numericUpDownMinimum"/> and corrects it, if necessary.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void NumericUpDownMaximum_ValueChanged(object sender, EventArgs e)
        {
            if (this.numericUpDownMaximum.Value <= this.numericUpDownMinimum.Value)
                this.numericUpDownMaximum.Value = this.numericUpDownMinimum.Value + decimal.One;
        }

        /// <summary>
        /// Switch Smooth all curves.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void CheckBoxSmooth_CheckedChanged(object sender, EventArgs e)
        {
            LineItem lineItem;
            for (int index = 0; index < this.zedGraphControlTest.GraphPane.CurveList.Count; index++)
            {
                lineItem = (LineItem)this.zedGraphControlTest.GraphPane.CurveList[index];
                lineItem.Line.IsSmooth = this.checkBoxSmooth.Checked;
                lineItem.Line.SmoothTension = 1.0F;
            }
            this.zedGraphControlTest.Invalidate();
        }

        /// <summary>
        /// Deletes all curves from the graph.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonClear_Click(object sender, EventArgs e)
        {
            this.zedGraphControlTest.GraphPane.CurveList.Clear();
            this.zedGraphControlTest.Invalidate();
        }
        #endregion

        #region methods regarding tabpage "Distributions II"
        /// <summary>
        /// Selects all random distributions in the checked listbox.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonSelectAll_Click(object sender, EventArgs e)
        {
            for (int index = 0; index < this.checkedListBoxDistributions.Items.Count; index++)
                this.checkedListBoxDistributions.SetItemChecked(index, true);
        }

        /// <summary>
        /// Deselects all random distributions in the checked listbox.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonDeselectAll_Click(object sender, EventArgs e)
        {
            for (int index = 0; index < this.checkedListBoxDistributions.Items.Count; index++)
                this.checkedListBoxDistributions.SetItemChecked(index, false);
        }

        /// <summary>
        /// Tests the selected random number distributions.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void buttonTest2_Click(object sender, EventArgs e)
        {
            this.richTextBoxDistributionTest.Clear();
            if (this.checkedListBoxDistributions.CheckedItems.Count == 0)
            {
                this.checkedListBoxDistributions.Text = "Choose at least one distribution to test";
                return;
            }

            this.buttonTest2.Enabled = false;
            this.buttonSelectAll.Enabled = false;
            this.buttonDeselectAll.Enabled = false;
            this.numericUpDownSamples2.Enabled = false;
            this.checkedListBoxDistributions.Enabled = false;
            this.comboBoxGenerator2.Enabled = false;
            this.Update();

            Distribution distribution;
            int samples = (int)this.numericUpDownSamples2.Value;
            double duration;
            Stopwatch watch = new Stopwatch();
            List<string> results = new List<string>(this.distributions.Count);

            // Do some computation before testing, cause otherwise the first tested distribution will have worse results.
            // Guess this needs to be done due to scheduling behaviour of the OS.
            distribution = new ContinuousUniformDistribution();
            for (int index2 = 0; index2 < 10000000; index2++)
            {
                distribution.NextDouble();
            }

            // Iterate over the list of random number distributions and test all that are checked in the ListBox.
            for (int index = 0; index < this.distributions.Count; index++)
            {
                if (this.checkedListBoxDistributions.CheckedItems.Contains(this.distributions.Values[index].Name))
                {
                    if (this.comboBoxGenerator2.SelectedIndex == 0)
                    {
                        distribution = (Distribution)Activator.CreateInstance(this.distributions.Values[index]);
                    }
                    else if (this.distributions.Values[index].GetConstructor(new Type[] { this.typeGenerator }) != null)
                    {
                        distribution = (Distribution)Activator.CreateInstance(this.distributions.Values[index],
                            new object[] { Activator.CreateInstance(this.generators[this.comboBoxGenerator2.Text]) });
                    }
                    else
                    {
                        distribution = (Distribution)Activator.CreateInstance(this.distributions.Values[index]);
                        if (this.richTextBoxDistributionTest.Text == "")
                        {
                            this.richTextBoxDistributionTest.Text += "The following distributions don't support a specific " +
                            "generator (Use distribution default).\n";
                        }
                        this.richTextBoxDistributionTest.Text += this.distributions.Values[index].Name + "\n";
                    }

                    //Test the NextDouble method.
                    watch.Reset();
                    watch.Start();
                    for (int index2 = 0; index2 < samples; index2++)
                    {
                        distribution.NextDouble();
                    }
                    watch.Stop();
                    duration = (double)watch.ElapsedTicks / (double)Stopwatch.Frequency;
                    results.Add("  " + duration.ToString("00.0000") + " s\t|  " + this.distributions.Values[index].Name + "\n");
                }
            }
            results.Sort();
            if (this.richTextBoxDistributionTest.Text != "")
            {
                this.richTextBoxDistributionTest.Text += "\n";
            }
            this.richTextBoxDistributionTest.Text += "  NextDouble()\t|  Distribution\n";
            for (int index = 0; index < results.Count; index++)
            {
                this.richTextBoxDistributionTest.Text += results[index];
            }
                
            this.buttonTest2.Enabled = true;
            this.buttonSelectAll.Enabled = true;
            this.buttonDeselectAll.Enabled = true;
            this.numericUpDownSamples2.Enabled = true;
            this.checkedListBoxDistributions.Enabled = true;
            this.comboBoxGenerator2.Enabled = true;
        }
        #endregion

        #region methods regarding generators
        /// <summary>
        /// Tests the selected random number generators.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonTestGenerators_Click(object sender, EventArgs e)
        {
            this.dataGridViewGenerators.Rows.Clear();
            if (this.checkedListBoxGenerators.CheckedItems.Count == 0)
            {
                return;
            }

            this.buttonTestGenerators.Enabled = false;
            this.buttonSelect.Enabled = false;
            this.buttonDeselect.Enabled = false;
            this.numericUpDownGenSamples.Enabled = false;
            this.checkedListBoxGenerators.Enabled = false;
            this.checkBoxNext.Enabled = false;
            this.checkBoxNextBoolean.Enabled = false;
            this.checkBoxNextBytes.Enabled = false;
            this.checkBoxNextDouble.Enabled = false;
            this.checkBoxNextDoubleMax.Enabled = false;
            this.checkBoxNextDoubleMinMax.Enabled = false;
            this.checkBoxNextMax.Enabled = false;
            this.checkBoxNextMinMax.Enabled = false;
            this.Update();
           
            Generator generator;
            double samplesPerSec;
            Stopwatch watch = new Stopwatch();
            int samples = (int)this.numericUpDownGenSamples.Value;
            string[] resultsRow;

            // Do some computation before testing, cause otherwise the first tested generator will have worse results.
            // Guess this needs to be done due to scheduling behaviour of the OS.
            generator = new StandardGenerator();
            for (int index2 = 0; index2 < 10000000; index2++)
            {
                generator.Next();
            }

            // Iterate over the list of random number generators and test all that are checked in the ListBox.
            for (int index = 0; index < this.generators.Count; index++)
            {
                if (this.checkedListBoxGenerators.CheckedItems.Contains(this.generators.Values[index].Name))
                {
                    resultsRow = new string[10];
                    resultsRow[0] = this.generators.Values[index].Name;
                    generator = (Generator)Activator.CreateInstance(this.generators.Values[index]);
                    
                    //Test the next method.
                    if (this.checkBoxNext.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.Next();
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[1] = samplesPerSec.ToString("#,0");
                    }

                    //Test the Next method with maxValue.
                    if (this.checkBoxNextMax.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.Next(99);
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[2] = samplesPerSec.ToString("#,0");
                    }

                    //Test the Next method with minValue and maxValue.
                    if (this.checkBoxNextMinMax.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.Next(-99, 99);
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[3] = samplesPerSec.ToString("#,0");
                    }

                    //Test the NextDouble method.
                    if (this.checkBoxNextDouble.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.NextDouble();
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[4] = samplesPerSec.ToString("#,0");
                    }

                    //Test the NextDouble method with maxValue.
                    if (this.checkBoxNextDoubleMax.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.NextDouble(99.0);
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[5] = samplesPerSec.ToString("#,0");
                    }

                    //Test the NextDouble method with minValue and maxValue.
                    if (this.checkBoxNextDoubleMinMax.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.NextDouble(-99.0, 99.0);
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[6] = samplesPerSec.ToString("#,0");
                    }

                    //Test the NextBoolean method
                    if (this.checkBoxNextBoolean.Checked)
                    {
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.NextBoolean();
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[7] = samplesPerSec.ToString("#,0");
                    }

                    //Test the NextBytes method
                    if (this.checkBoxNextBytes.Checked)
                    {
                        byte[] bytes = new byte[64];
                        watch.Reset();
                        watch.Start();
                        for (int index2 = 0; index2 < samples; index2++)
                        {
                            generator.NextBytes(bytes);
                        }
                        watch.Stop();
                        samplesPerSec = Math.Floor((double)samples / (double)watch.ElapsedTicks * (double)Stopwatch.Frequency);
                        resultsRow[8] = samplesPerSec.ToString("#,0");
                    }

                    resultsRow[9] = "samples/s";
                    this.dataGridViewGenerators.Rows.Add(resultsRow);
                    this.dataGridViewGenerators.Update();
                }
            }

            this.buttonTestGenerators.Enabled = true;
            this.buttonSelect.Enabled = true;
            this.buttonDeselect.Enabled = true;
            this.numericUpDownGenSamples.Enabled = true;
            this.checkedListBoxGenerators.Enabled = true;
            this.checkBoxNext.Enabled = true;
            this.checkBoxNextBoolean.Enabled = true;
            this.checkBoxNextBytes.Enabled = true;
            this.checkBoxNextDouble.Enabled = true;
            this.checkBoxNextDoubleMax.Enabled = true;
            this.checkBoxNextDoubleMinMax.Enabled = true;
            this.checkBoxNextMax.Enabled = true;
            this.checkBoxNextMinMax.Enabled = true;
        }

        /// <summary>
        /// Selects all random generators in the checked listbox.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonSelect_Click(object sender, EventArgs e)
        {
            for (int index = 0; index < this.checkedListBoxGenerators.Items.Count; index++)
                this.checkedListBoxGenerators.SetItemChecked(index, true);
        }

        /// <summary>
        /// Deselects all random generators in the checked listbox.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void ButtonDeselect_Click(object sender, EventArgs e)
        {
            for (int index = 0; index < this.checkedListBoxGenerators.Items.Count; index++)
                this.checkedListBoxGenerators.SetItemChecked(index, false);
        }
        
        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void CheckBoxNext_CheckedChanged(object sender, EventArgs e)
        {
            this.Next.Visible = this.checkBoxNext.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextMax_CheckedChanged(object sender, EventArgs e)
        {
            this.NextMax.Visible = this.checkBoxNextMax.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextMinMax_CheckedChanged(object sender, EventArgs e)
        {
            this.NextMinMax.Visible = this.checkBoxNextMinMax.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextDouble_CheckedChanged(object sender, EventArgs e)
        {
            this.NextDouble.Visible = this.checkBoxNextDouble.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextDoubleMax_CheckedChanged(object sender, EventArgs e)
        {
            this.NextDoubleMax.Visible = this.checkBoxNextDoubleMax.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextDoubleMinMax_CheckedChanged(object sender, EventArgs e)
        {
            this.NextDoubleMinMax.Visible = this.checkBoxNextDoubleMinMax.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextBoolean_CheckedChanged(object sender, EventArgs e)
        {
            this.NextBoolean.Visible = this.checkBoxNextBoolean.Checked;
        }

        /// <summary>
        /// Changes the visibility of column.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">An <see cref="EventArgs"/> object that contains the event data.</param>
        private void checkBoxNextBytes_CheckedChanged(object sender, EventArgs e)
        {
            this.NextBytes.Visible = this.checkBoxNextBytes.Checked;
        }
        #endregion

        /// <summary>
        /// Formats a value of type <see cref="double"/> according to its absolute value.
        /// </summary>
        /// <param name="value">The value to format.</param>
        /// <returns>The formatted value.</returns>
        private string FormatDouble(double value)
        {
            if (Math.Abs(value) >= 1000000 || (Math.Abs(value) < 0.001 && value != 0))
                return value.ToString("0.###e+0");
            else
                return value.ToString("0.###");
        }
        #endregion
    }
}
