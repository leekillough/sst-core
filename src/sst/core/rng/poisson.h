// Copyright 2009-2025 NTESS. Under the terms
// of Contract DE-NA0003525 with NTESS, the U.S.
// Government retains certain rights in this software.
//
// Copyright (c) 2009-2025, NTESS
// All rights reserved.
//
// This file is part of the SST software package. For license
// information, see the LICENSE file in the top level directory of the
// distribution.

#ifndef SST_CORE_RNG_POISSON_H
#define SST_CORE_RNG_POISSON_H

#include "distrib.h"
#include "math.h"
#include "mersenne.h"
#include "rng.h"

namespace SST::RNG {

/**
    \class PoissonDistribution poisson.h "sst/core/rng/poisson.h"

    Creates an Poisson distribution for use within SST. This distribution is the same across
    platforms and compilers.
*/
class PoissonDistribution : public RandomDistribution
{

public:
    /**
        Creates an Poisson distribution with a specific lambda
        \param mn The lambda of the Poisson distribution
    */
    PoissonDistribution(const double mn) : RandomDistribution(), lambda(mn)
    {

        baseDistrib   = new MersenneRNG();
        deleteDistrib = true;
    }

    /**
        Creates an Poisson distribution with a specific lambda and a base random number generator
        \param lambda The lambda of the Poisson distribution
        \param baseDist The base random number generator to take the distribution from.
    */
    PoissonDistribution(const double mn, Random* baseDist) : RandomDistribution(), lambda(mn)
    {

        baseDistrib   = baseDist;
        deleteDistrib = false;
    }

    /**
        Destroys the Poisson distribution
    */
    ~PoissonDistribution()
    {
        if ( deleteDistrib ) { delete baseDistrib; }
    }

    /**
        Gets the next (random) double value in the distribution
        \return The next random double from the distribution
    */
    double getNextDouble() override
    {
        const double L = exp(-lambda);
        double       p = 1.0;
        int          k = 0;

        do {
            k++;
            p *= baseDistrib->nextUniform();
        } while ( p > L );

        return k - 1;
    }

    /**
        Gets the lambda with which the distribution was created
        \return The lambda which the user created the distribution with
    */
    double getLambda() { return lambda; }

    /**
        Default constructor. FOR SERIALIZATION ONLY.
     */
    PoissonDistribution() : RandomDistribution(), lambda(1.0) {}

    /**
        Serialization function for checkpoint
    */
    void serialize_order(SST::Core::Serialization::serializer& ser) override
    {
        ser& const_cast<double&>(lambda);
        ser& baseDistrib;
        ser& deleteDistrib;
    }

    /**
        Serialization macro
    */
    ImplementSerializable(PoissonDistribution)

protected:
    /**
        Sets the lambda of the Poisson distribution.
    */
    const double lambda;
    /**
        Sets the base random number generator for the distribution.
    */
    Random*      baseDistrib;

    /**
        Controls whether the base distribution should be deleted when this class is destructed.
    */
    bool deleteDistrib;
};

using SSTPoissonDistribution = PoissonDistribution;

} // namespace SST::RNG

#endif // SST_CORE_RNG_POISSON_H
