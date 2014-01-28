using System;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;

namespace DifferentialEvolution
{
    public class DifferentialEvolution
    {
        // class members
        public delegate OutputFunction FunctionPointer(double[] paras, InputStructure S_in);
        private static FunctionPointer minimizingfunction;
        //public FileWrite fwrite1;

        // constructor
        public DifferentialEvolution(FunctionPointer minimizingfunction_)// string fileLoc)
        {
            minimizingfunction = minimizingfunction_;
            //fwrite1 = new FileWrite(fileLoc);
        }

        public OptimizerOutput Optimizer(InputStructure inputstructurevar)
        {
            // working variables just for notational convenience and to keep the code uncluttered
            int I_popnumber = inputstructurevar.I_NP;
            double F_weight = inputstructurevar.F_weight;
            double F_crossoverprob = inputstructurevar.F_CR;
            int I_dimensionspara = inputstructurevar.I_D;
            double[] FVr_minbound = new double[inputstructurevar.FVr_minbound.Length];
            Copy1DArrayL2R(inputstructurevar.FVr_minbound, ref FVr_minbound);
            double[] FVr_maxbound = new double[inputstructurevar.FVr_maxbound.Length];
            Copy1DArrayL2R(inputstructurevar.FVr_maxbound, ref FVr_maxbound);
            bool I_bnd_constr = inputstructurevar.I_bnd_constr;
            int I_itermax = inputstructurevar.I_itermax;
            double F_thresholdmin = inputstructurevar.F_VTR;
            int I_strategy = inputstructurevar.I_strategy;
            int I_refresh = inputstructurevar.I_refresh;

            int i, j, k;

            Random rand = new Random();

            // Check input variables

            if (I_popnumber < 5)
            {
                I_popnumber = 5;
                //fwrite1.sw.WriteLine("I_NP increased to minimal value 5");

            }

            if ((F_crossoverprob < 0) || (F_crossoverprob > 1))
            {
                F_crossoverprob = 0.5;
                //fwrite1.sw.WriteLine("F_CR should be from interval [0,1]; set to default value 0.5");

            }

            if (I_itermax <= 0)
            {
                I_itermax = 200;
                //fwrite1.sw.WriteLine("I_itermax should be > 0; set to default value 200");
                //MessageBox.Show("I_itermax should be > 0; set to default value 200", "Note");
            }

            // Initialize population and some arrays

            double[,] FM_pop = new double[I_popnumber, I_dimensionspara];

            // FM_pop is a matrix of size I_NPxI_D. It will be initialized with random variables
            // between the min and max value of the parameters.

            for (k = 0; k < I_popnumber; k++)
            {
                for (j = 0; j < I_dimensionspara; j++)
                {
                    FM_pop[k, j] = FVr_minbound[j] + rand.NextDouble() * (FVr_maxbound[j] - FVr_minbound[j]);
                }
            }

            double[,] FM_popold = new double[I_popnumber, I_dimensionspara]; // toggle population
            double[] FVr_bestmem = new double[I_dimensionspara];      // best population memeber ever
            double[] FVr_bestmemit = new double[I_dimensionspara];    // best population memeber in iteration
            int I_nfeval = 0;                            // number of function evaluations

            ////////Evaluate the best member after initialization//////////////

            int I_best_index = 0;                           // start with first population member
            double[] FM_poprow = new double[I_dimensionspara];

            FM_poprow = Get_ith_row(FM_pop, I_best_index);

            OutputFunction[] S_val = new OutputFunction[I_popnumber];

            S_val[0] = minimizingfunction(FM_poprow, inputstructurevar);

            OutputFunction S_bestval = new OutputFunction(0, 1);

            Copy_outfunL2R(S_val[0], ref S_bestval);        // best objective function value so far

            I_nfeval = I_nfeval + 1;

            for (k = 1; k < I_popnumber; k++)                      // check the remaining members
            {
                FM_poprow = Get_ith_row(FM_pop, k);
                S_val[k] = minimizingfunction(FM_poprow, inputstructurevar);
                I_nfeval = I_nfeval + 1;
                if (left_win(S_val[k], S_bestval))
                {
                    I_best_index = k;                       // save its location
                    Copy_outfunL2R(S_val[k], ref S_bestval);
                }
            }
            Copy1DArrayL2R(Get_ith_row(FM_pop, I_best_index), ref FVr_bestmemit);

            OutputFunction S_bestvalit = new OutputFunction(0, 1);

            // best value of current iteration
            Copy_outfunL2R(S_bestval, ref S_bestvalit);

            // best member ever
            Copy1DArrayL2R(FVr_bestmemit, ref FVr_bestmem);

            // DE-Minimization
            // FM_popold is the population which has to compete. It is
            // static through one iteration. FM_pop is the newly emerging population.

            double[,] FM_pm1 = new double[I_popnumber, I_dimensionspara]; //initialize population matrix 1
            double[,] FM_pm2 = new double[I_popnumber, I_dimensionspara]; //initialize population matrix 2
            double[,] FM_pm3 = new double[I_popnumber, I_dimensionspara]; //initialize population matrix 3
            double[,] FM_pm4 = new double[I_popnumber, I_dimensionspara]; //initialize population matrix 4
            double[,] FM_pm5 = new double[I_popnumber, I_dimensionspara]; //initialize population matrix 5
            double[,] FM_origin = new double[I_popnumber, I_dimensionspara];

            double[,] FM_bm = new double[I_popnumber, I_dimensionspara];  //initialize FVr_bestmember  matrix
            double[,] FM_ui = new double[I_popnumber, I_dimensionspara];  //intermediate population of perturbed vectors
            double[,] FM_mui = new double[I_popnumber, I_dimensionspara]; //mask for intermediate population
            double[,] FM_mpo = new double[I_popnumber, I_dimensionspara]; //mask for old population

            int[] FVr_rot = new int[I_popnumber];      //rotating index array (size I_NP)
            for (i = 0; i < I_popnumber; i++)
            {
                FVr_rot[i] = i;
            }

            int[] FVr_rotd = new int[I_dimensionspara];      //rotating index array (size I_D)
            for (i = 0; i < I_dimensionspara; i++)
            {
                FVr_rotd[i] = i;
            }

            int[] FVr_rt = new int[I_popnumber];      //another rotating index array
            int[] FVr_rtd = new int[I_dimensionspara];      //rotating index array for exponential crossover

            int[] FVr_a1 = new int[I_popnumber];      //index array
            int[] FVr_a2 = new int[I_popnumber];      //index array
            int[] FVr_a3 = new int[I_popnumber];      //index array
            int[] FVr_a4 = new int[I_popnumber];      //index array
            int[] FVr_a5 = new int[I_popnumber];      //index array

            int[] FVr_ind = new int[4];

            double[,] FM_meanv = new double[I_popnumber, I_dimensionspara];
            Ones(ref FM_meanv);

            int I_iter = 1;

            while ((I_iter < I_itermax) && (S_bestval.FVr_oa[0] > F_thresholdmin))
            {
                // save the old population
                Copy2DArrayL2R(FM_pop, ref FM_popold);
                Copy2DArrayL2R(FM_pop, ref inputstructurevar.FM_pop);
                Copy1DArrayL2R(FVr_bestmem, ref inputstructurevar.FVr_bestmem);

                FVr_ind = randperm(4);      //index pointer array

                FVr_a1 = randperm(I_popnumber);    //shuffle locations of vectors

                #region MyLoops

                int tmp1;

                for (i = 0; i < I_popnumber; i++)  //rotate indices by ind(0) positions
                {
                    FVr_rt[i] = (FVr_rot[i] + FVr_ind[0])%I_popnumber;
                    FVr_a2[i] = FVr_a1[FVr_rt[i]]; // no need for +1 here as we are using C#
                }

                for (i = 0; i < I_popnumber; i++)  //rotate indices by ind(1) positions
                {
                    FVr_rt[i] =(FVr_rot[i] + FVr_ind[1])%I_popnumber;
                    FVr_a3[i] = FVr_a2[FVr_rt[i]];
                }

                for (i = 0; i < I_popnumber; i++)  //rotate indices by ind(2) positions
                {
                    FVr_rt[i] = (FVr_rot[i] + FVr_ind[2])% I_popnumber;
                    FVr_a4[i] = FVr_a3[FVr_rt[i]];
                }

                for (i = 0; i < I_popnumber; i++)  //rotate indices by ind(3) positions
                {
                    FVr_rt[i] = (FVr_rot[i] + FVr_ind[3])% I_popnumber;
                    FVr_a5[i] = FVr_a4[FVr_rt[i]];
                }

                #endregion

                for (i = 0; i < I_popnumber; i++)
                {
                    for (j = 0; j < I_dimensionspara; j++)
                    {
                        FM_pm1[i, j] = FM_popold[FVr_a1[i], j];
                        FM_pm2[i, j] = FM_popold[FVr_a2[i], j];
                        FM_pm3[i, j] = FM_popold[FVr_a3[i], j];
                        FM_pm4[i, j] = FM_popold[FVr_a4[i], j];
                        FM_pm5[i, j] = FM_popold[FVr_a5[i], j];
                    }
                }

                for (i = 0; i < I_popnumber; i++)
                {
                    for (j = 0; j < I_dimensionspara; j++)
                    {
                        FM_bm[i, j] = FVr_bestmemit[j];
                    }
                }

                for (i = 0; i < I_popnumber; i++)
                {
                    for (j = 0; j < I_dimensionspara; j++)
                    {
                        if (rand.NextDouble() < F_crossoverprob)
                        {
                            FM_mui[i, j] = 1;
                        }
                        else
                        {
                            FM_mui[i, j] = 0;
                        }
                    }
                }

                // Insert this code if you want exponential crossover

                //FM_mui = Sort(Transpose(FM_mui));
                //int n;
                //for (k = 0; k < I_NP; k++)
                //{
                //    n = Math.Floor(rand.NextDouble() * I_D);
                //    for (i = 0; i < I_D; i++) // changed a little
                //    {
                //        FVr_rtd[i] = Math.DivRem(FVr_rotd[i] + n, I_D);
                //        FM_mui[i, k] = FM_mui[FVr_rtd[i], k];
                //    }

                //}

                //FM_mui = Transpose(FM_mui);

                ///////// End of exponential crossover ////////

                for (i = 0; i < I_popnumber; i++)
                {
                    for (j = 0; j < I_dimensionspara; j++)
                    {
                        if (FM_mui[i, j] < 0.5)
                        {
                            FM_mpo[i, j] = 1;
                        }
                        else
                        {
                            FM_mpo[i, j] = 0;
                        }
                    }
                }

                if (I_strategy == 1)
                {
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_pm3[i, j] + F_weight * (FM_pm1[i, j] - FM_pm2[i, j]);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];
                    Copy2DArrayL2R(FM_pm3, ref FM_origin);
                }
                else if (I_strategy == 2)
                {
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] + F_weight * (FM_bm[i, j] - FM_popold[i, j]) + F_weight * (FM_pm1[i, j] - FM_pm2[i, j]);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];
                    Copy2DArrayL2R(FM_popold, ref FM_origin);
                }
                else if (I_strategy == 3)
                {
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_bm[i, j] + (FM_pm1[i, j] - FM_pm2[i, j]) * ((1 - 0.9999) * rand.NextDouble() + F_weight);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];
                    Copy2DArrayL2R(FM_bm, ref FM_origin);
                }
                else if (I_strategy == 4)
                {
                    double[] f1 = new double[I_popnumber];
                    for (i = 0; i < I_popnumber; i++)
                        f1[i] = ((1 - F_weight) * rand.NextDouble() + F_weight);
                    for (j = 0; j < I_dimensionspara; j++)
                        for (i = 0; i < I_popnumber; i++)
                            FM_pm5[i, j] = f1[i];
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_pm3[i, j] + (FM_pm1[i, j] - FM_pm2[i, j]) * FM_pm5[i, j];
                    Copy2DArrayL2R(FM_pm3, ref FM_origin);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];

                }
                else if (I_strategy == 5)
                {
                    double f1 = ((1 - F_weight) * rand.NextDouble() + F_weight);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_pm3[i, j] + (FM_pm1[i, j] - FM_pm2[i, j]) * f1;
                    Copy2DArrayL2R(FM_pm3, ref FM_origin);
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];

                }
                else
                {
                    if (rand.NextDouble() < 0.5)
                    {
                        for (i = 0; i < I_popnumber; i++)
                            for (j = 0; j < I_dimensionspara; j++)
                                FM_ui[i, j] = FM_pm3[i, j] + (FM_pm1[i, j] - FM_pm2[i, j]) * F_weight;
                        Copy2DArrayL2R(FM_pm3, ref FM_origin);
                    }
                    else
                    {
                        for (i = 0; i < I_popnumber; i++)
                            for (j = 0; j < I_dimensionspara; j++)
                                FM_ui[i, j] = FM_pm3[i, j] + (FM_pm1[i, j] + FM_pm2[i, j] - 2 * FM_pm3[i, j]) * (F_weight + 1.0) * 0.5;
                        Copy2DArrayL2R(FM_pm3, ref FM_origin);
                    }
                    for (i = 0; i < I_popnumber; i++)
                        for (j = 0; j < I_dimensionspara; j++)
                            FM_ui[i, j] = FM_popold[i, j] * FM_mpo[i, j] + FM_ui[i, j] * FM_mui[i, j];
                }

                // Optional parent + child selection

                // Select which vectors are allowed to enter the new population

                for (k = 0; k < I_popnumber; k++)
                {
                    // Only use this if boundary constraints are needed
                    if (I_bnd_constr == true)
                    {
                        for (j = 0; j < I_dimensionspara; j++)
                        {
                            if (FM_ui[k, j] > FVr_maxbound[j])
                                FM_ui[k, j] = FVr_maxbound[j] + rand.NextDouble() * (FM_origin[k, j] - FVr_maxbound[j]);
                            if (FM_ui[k, j] < FVr_minbound[j])
                                FM_ui[k, j] = FVr_minbound[j] + rand.NextDouble() * (FM_origin[k, j] - FVr_minbound[j]);
                        }
                    }
                    // End boundary constraints

                    OutputFunction S_tempval = new OutputFunction();
                    S_tempval = minimizingfunction(Get_ith_row(FM_ui, k), inputstructurevar);
                    I_nfeval = I_nfeval + 1;

                    if (left_win(S_tempval, S_val[k]) == true)
                    {
                        for (i = 0; i < I_dimensionspara; i++)
                            FM_pop[k, i] = FM_ui[k, i];
                        Copy_outfunL2R(S_tempval, ref S_val[k]);

                        // we update S_bestval only in case of success to save time
                        if (left_win(S_tempval, S_bestval) == true)
                        {
                            Copy_outfunL2R(S_tempval, ref S_bestval);
                            Copy1DArrayL2R(Get_ith_row(FM_ui, k), ref FVr_bestmem);
                        }
                    }

                } // for

                Copy1DArrayL2R(FVr_bestmem, ref FVr_bestmemit); // freeze the best member of this iteration for the coming 
                // iteration. This is needed for some of the strategies.

                //if (I_refresh > 0)
                //{
                //    int temp1;
                //    if (Math.DivRem(I_iter, I_refresh, out temp1) == 0 || I_refresh == 1)
                //    {
                //        fwrite1.sw.WriteLine(I_iter.ToString() + ", " + DoubleArray2String(FVr_bestmem) + ", " + DoubleArray2String(S_bestval.FVr_oa));
                //    }
                //}

                I_iter = I_iter + 1;
            }

            //fwrite1.sw.Close();

            OptimizerOutput S_outMain1 = new OptimizerOutput(FVr_bestmem, S_bestval, I_nfeval);
            return S_outMain1;

        }


        #region MyFunctions
        // left_win(S_x,S_y) takes structures S_x and S_y as an argument.
        // The function returns 1 if the left structure of the input structures,
        // i.e. S_x, wins. If the right structure, S_y, wins, the result is 0. 

        public bool left_win(OutputFunction S_x, OutputFunction S_y)
        {
            bool result = true;

            if (S_x.I_nc > 0)
            {
                for (int i = 0; i < S_x.I_nc; i++)
                {
                    if (S_x.FVr_ca[i] > 0)
                        if (S_x.FVr_ca[i] > S_y.FVr_ca[i])
                            result = false;
                }
            }

            if (S_x.I_no > 0)
            {
                for (int k = 0; k < S_x.I_no; k++)
                {
                    if (S_x.FVr_oa[k] > S_y.FVr_oa[k])
                        result = false;
                }
            }

            return result;
        }


        // create ones vector
        public void Ones(ref double[] vec)
        {
            for (int i = 0; i < vec.Length; i++)
                vec[i] = 1.0;
        }

        // create ones matrix
        public void Ones(ref double[,] mat)
        {
            for (int i = 0; i <= mat.GetUpperBound(0); i++)
                for (int j = 0; j <= mat.GetUpperBound(1); j++)
                    mat[i, j] = 1.0;
        }

        // copy contents of one array into another
        public static void Copy1DArrayL2R(double[] left, ref double[] right)
        {
            if (left.Length == right.Length)
            {
                for (int i = 0; i < left.Length; i++)
                {
                    right[i] = left[i];
                }
            }
        }

        public static void Copy2DArrayL2R(double[,] left, ref double[,] right)
        {
            if (left.Length == right.Length)
            {
                for (int i = 0; i <= left.GetUpperBound(0); i++)
                {
                    for (int j = 0; j <= left.GetUpperBound(1); j++)
                    {
                        right[i, j] = left[i, j];
                    }
                }
            }
        }


        // Get ith row from the matrix
        public double[] Get_ith_row(double[,] Mat, int i)
        {
            double[] tmp = new double[Mat.GetUpperBound(1) + 1];

            for (int j = 0; j <= Mat.GetUpperBound(1); j++)
            {
                tmp[j] = Mat[i, j];
            }

            return tmp;
        }

        // Get ith column from a matrix
        public double[] Get_ith_col(double[,] Mat, int i)
        {
            double[] tmp = new double[Mat.GetUpperBound(0) + 1];

            for (int j = 0; j <= Mat.GetUpperBound(0); j++)
            {
                tmp[j] = Mat[j, i];
            }

            return tmp;
        }

        // Copy left values to right...
        public static void Copy_outfunL2R(OutputFunction left, ref OutputFunction right)
        {
            right.I_nc = left.I_nc;
            right.I_no = left.I_no;
            Copy1DArrayL2R(left.FVr_ca, ref right.FVr_ca);
            Copy1DArrayL2R(left.FVr_oa, ref right.FVr_oa);
        }

        public int[] randperm(int m)
        {
            int[] index = new int[m];
            int tempi;
            double[] randArray = new double[m];
            double tempd;
            Random rand = new Random();


            for (int i = 0; i < m; i++)
            {
                randArray[i] = rand.NextDouble();
                index[i] = i;
            }

            // sort the numbers in randarray, also modify index
            for (int i = 0; i < m - 1; i++)
                for (int j = 0; j < m - i - 1; j++)
                    if (randArray[j + 1] < randArray[j])
                    {
                        tempd = randArray[j];
                        randArray[j] = randArray[j + 1];
                        randArray[j + 1] = tempd;
                        tempi = index[j];
                        index[j] = index[j + 1];
                        index[j + 1] = tempi;
                    }
            return index;
        }

        public double[,] Transpose(double[,] Mat)
        {
            double[,] result = new double[Mat.GetUpperBound(1) + 1, Mat.GetUpperBound(0) + 1];
            for (int i = 0; i <= Mat.GetUpperBound(0); i++)
                for (int j = 0; j <= Mat.GetUpperBound(1); j++)
                    result[j, i] = Mat[i, j];

            return result;
        }

        public double[] Sort(double[] Unsorted)
        {
            double[] Sorted = new double[Unsorted.Length];
            Copy1DArrayL2R(Unsorted, ref Sorted);
            double temp;

            for (int i = 0; i < Sorted.Length - 1; i++)
            {
                for (int j = 0; j < Sorted.Length - 1 - i; j++)
                {
                    if (Sorted[j + 1] < Sorted[j])
                    {
                        temp = Sorted[j];
                        Sorted[j] = Sorted[j + 1];
                        Sorted[j + 1] = temp;
                    }
                }
            }

            return Sorted;
        }

        public double[,] Sort(double[,] Unsorted)
        {
            double[,] Sorted = new double[Unsorted.GetUpperBound(0) + 1, Unsorted.GetUpperBound(1) + 1];
            Copy2DArrayL2R(Unsorted, ref Sorted);
            double temp;

            for (int k = 0; k <= Sorted.GetUpperBound(1); k++)
            {
                for (int i = 0; i < Sorted.GetUpperBound(0); i++)
                {
                    for (int j = 0; j < Sorted.GetUpperBound(0) - i; j++)
                    {
                        if (Sorted[j + 1, k] < Sorted[j, k])
                        {
                            temp = Sorted[j, k];
                            Sorted[j, k] = Sorted[j + 1, k];
                            Sorted[j + 1, k] = temp;
                        }
                    }
                }
            }

            return Sorted;
        }

        public string DoubleArray2String(double[] arrayIn)
        {
            string output = arrayIn[0].ToString();
            for (int i = 1; i < arrayIn.Length; i++)
            {
                output = output + ", " + arrayIn[i].ToString();
            }

            return output;

        }




        #endregion


    }

    #region MyStructs

    public struct InputStructure
    {
        public int I_NP; // Number of population members
        public double F_weight; // DE-stepsize F_weight from interval [0, 2]
        public double F_CR; // Crossover probability constant from interval [0, 1].
        public int I_D; // Number of parameters of the objective function.
        //*** note: these are not bound constraints!! ***//
        public double[] FVr_minbound; // Vector of lower bounds FVr_minbound(1) ... FVr_minbound(I_D) of initial population.
        public double[] FVr_maxbound; // Vector of upper bounds FVr_maxbound(1) ... FVr_maxbound(I_D) of initial population.
        public bool I_bnd_constr; // true: use bounds as bound constraints, false: no bound constraints
        public int I_itermax; // maximum number of iterations (generations)
        public double F_VTR; // "Value To Reach" (stop when ofunc < F_VTR)
        public int I_strategy;
        //                1 --> DE/rand/1:
        //                      the classical version of DE.
        //                2 --> DE/local-to-best/1:
        //                      a version which has been used by quite a number
        //                      of scientists. Attempts a balance between robustness
        //                      and fast convergence.
        //                3 --> DE/best/1 with jitter:
        //                      taylored for small population sizes and fast convergence.
        //                      Dimensionality should not be too high.
        //                4 --> DE/rand/1 with per-vector-dither:
        //                      Classical DE with dither to become even more robust.
        //                5 --> DE/rand/1 with per-generation-dither:
        //                      Classical DE with dither to become even more robust.
        //                      Choosing F_weight = 0.3 is a good start here.
        //                6 --> DE/rand/1 either-or-algorithm:
        //                      Alternates between differential mutation and three-point-
        //                      recombination
        public int I_refresh; // intermediate output will be produced after "I_refresh" iterations. No intermediate output will be produced if I_refresh is < 1
        // public bool I_plotting; // we will not use this option.
        public double[,] FM_pop;
        public double[] FVr_bestmem;
    }

    public struct OutputFunction
    {
        public int I_nc; // no. of constraints
        public double[] FVr_ca; // constraint array
        public int I_no; // number of objectives (costs)
        public double[] FVr_oa; // objective array  

        public OutputFunction(int I_nc_, int I_no_)
        {
            I_nc = I_nc_;
            FVr_ca = new double[I_nc_ + 1];
            I_no = I_no_;
            FVr_oa = new double[I_no];
        }
    }

    public struct OptimizerOutput
    {
        public double[] FVr_bestmem;
        public OutputFunction S_bestval;
        public int I_nfeval;

        public OptimizerOutput(double[] FVr_bestmem_, OutputFunction S_bestval_, int I_nfeval_)
        {
            FVr_bestmem = new double[FVr_bestmem_.Length];
            DifferentialEvolution.Copy1DArrayL2R(FVr_bestmem_, ref FVr_bestmem);
            S_bestval = new OutputFunction(0, 1);
            DifferentialEvolution.Copy_outfunL2R(S_bestval_, ref S_bestval);
            I_nfeval = I_nfeval_;
        }

    }
    #endregion


}
