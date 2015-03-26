using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

// Inputs to the optimizer

//        int I_NP; // Number of population members
//        double F_weight; // DE-stepsize F_weight from interval [0, 2]
//        double F_CR; // Crossover probability constant from interval [0, 1].
//        int I_D; // Number of parameters of the objective function.
//        //*** note: these are not bound constraints!! ***//
//        double[] FVr_minbound; // Vector of lower bounds FVr_minbound(1) ... FVr_minbound(I_D) of initial population.
//        double[] FVr_maxbound; // Vector of upper bounds FVr_maxbound(1) ... FVr_maxbound(I_D) of initial population.
//        bool I_bnd_constr; // true: use bounds as bound constraints, false: no bound constraints
//        int I_itermax; // maximum number of iterations (generations)
//        double F_VTR; // "Value To Reach" (stop when ofunc < F_VTR)
//        int I_strategy;
//        //                1 --> DE/rand/1:
//        //                      the classical version of DE.
//        //                2 --> DE/local-to-best/1:
//        //                      a version which has been used by quite a number
//        //                      of scientists. Attempts a balance between robustness
//        //                      and fast convergence.
//        //                3 --> DE/best/1 with jitter:
//        //                      taylored for small population sizes and fast convergence.
//        //                      Dimensionality should not be too high.
//        //                4 --> DE/rand/1 with per-vector-dither:
//        //                      Classical DE with dither to become even more robust.
//        //                5 --> DE/rand/1 with per-generation-dither:
//        //                      Classical DE with dither to become even more robust.
//        //                      Choosing F_weight = 0.3 is a good start here.
//        //                6 --> DE/rand/1 either-or-algorithm:
//        //                      Alternates between differential mutation and three-point-
//        //                      recombination
//        int I_refresh; // intermediate output will be produced after "I_refresh" iterations. No intermediate output will be produced if I_refresh is < 1
//        // public bool I_plotting; // we will not use this option.
//        double[,] FM_pop;
//        double[] FVr_bestmem; // Solution

namespace DifferentialEvolution
{
    public partial class Form1 : Form
    {
        private int PopulationSize;
        private int NumberOfIterations;
        private int NumberOfParameters;
        private int Strategy;
        public static InputStructure S_Infun1;
        public static double[] bestParam;

        public Form1()
        {
            InitializeComponent();

            textBox1.Text = "2";
            textBox2.Text = "500";
            textBox3.Text = "100";

            comboBox1.Text = "2";

            label10.Text = "";
            label11.Text = "";
           
            label13.Text = "";
        }

        private void button1_Click(object sender, EventArgs e)
        {
            SetParas();

            // Configuring Differential evolution optimizer
            S_Infun1 = new InputStructure();
            S_Infun1.F_VTR = -100000; // Lower bound on the objective function

            S_Infun1.I_D = NumberOfParameters; // number of parameters to optimize

            S_Infun1.FVr_minbound = new double[S_Infun1.I_D]; // lower limit
            S_Infun1.FVr_maxbound = new double[S_Infun1.I_D];

            for (int i = 0; i < S_Infun1.I_D; i++)
            {
                S_Infun1.FVr_minbound[i] = -100;
                S_Infun1.FVr_maxbound[i] = 100;
            }

            S_Infun1.I_bnd_constr = true; // bound by lower and upper limits
            S_Infun1.I_NP = PopulationSize;
            S_Infun1.I_itermax = NumberOfIterations;
            S_Infun1.F_weight = 0.85;
            S_Infun1.F_CR = 1;
            S_Infun1.I_strategy = Strategy;
            S_Infun1.I_refresh = 1;

            S_Infun1.FVr_bestmem = new double[S_Infun1.I_D];
            S_Infun1.FM_pop = new double[S_Infun1.I_NP, S_Infun1.I_D];

            OptimizerOutput Output = new OptimizerOutput();

            
            DifferentialEvolution DE_optimizer = new DifferentialEvolution(new 
                DifferentialEvolution.FunctionPointer(ObjectiveFunction));

            Output = DE_optimizer.Optimizer(S_Infun1);            
            bestParam = Output.FVr_bestmem;

            label10.Text = bestParam[0].ToString("0.000");
            label11.Text = bestParam[1].ToString("0.000");
            
            label13.Text = (-Output.S_bestval.FVr_oa[0]).ToString("0.000");
            MessageBox.Show("Optimization Done");

        }

        private void SetParas()
        {
            try
            {
                PopulationSize = Int32.Parse(textBox2.Text);
                NumberOfIterations = Int32.Parse(textBox3.Text);
                NumberOfParameters = Int32.Parse(textBox1.Text);
                Strategy = Int32.Parse(comboBox1.Text);
            }
            catch(Exception ex)
            {
                MessageBox.Show(ex.Message + "\n Enter valid inputs ", "Error", 
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public OutputFunction ObjectiveFunction(double[] parameters, InputStructure S_In)
        {
            OutputFunction result = new OutputFunction();
            result.I_nc = 0; // any constrains??
            result.FVr_ca = new double[1] { 0 };
            result.I_no = 1; // number of outputs
            
            double x = parameters[0];
            double y = parameters[1];


            double z = 3 * Math.Pow((1 - x),  2) * Math.Exp(-(Math.Pow(x , 2)) - Math.Pow((y + 1) , 2))
                - 10 * (x / 5 - Math.Pow(x , 3) - Math.Pow(y , 5)) * Math.Exp(-Math.Pow(x , 2) 
                - Math.Pow(y , 2)) - 1 / 3 * Math.Exp(-Math.Pow((x + 1) , 2) - Math.Pow(y , 2));           

            result.FVr_oa = new double[1] { -z }; // it is a minimizer
            return result;
        }

        private void textBox4_TextChanged(object sender, EventArgs e)
        {

        }
    }
}
