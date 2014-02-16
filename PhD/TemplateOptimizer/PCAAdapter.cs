using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TemplateOptimizer
{
    class PCAAdapter
    {
        private Population population;

        public PCAAdapter( Population population )
        {
            this.population = population;
        }

        public double[,] Table
        {
            get
            {
                double[,] table = new double[population.TemplateCount, population.ComponentCount];
                int i = 0;
                foreach( var template in population.Templates )
                {
                    int j = 0;
                    foreach( var component in template.Components )
                    {
                        table[i, j++] = component;
                    }
                    i++;
                }
                return table;
            }
        }

    }
}
